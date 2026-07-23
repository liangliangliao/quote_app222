import 'dart:math' as math;

import 'mental_health_checkup_catalog.dart';
import 'mental_health_checkup_models.dart';

class _KabScores {
  final double? knowledge;
  final double? attitude;
  final double? behavior;
  final double? attitudeBehaviorConsistency;
  final double? knowledgeBehaviorConsistency;
  final double? integrated;
  final double? weakestLink;

  const _KabScores({
    required this.knowledge,
    required this.attitude,
    required this.behavior,
    required this.attitudeBehaviorConsistency,
    required this.knowledgeBehaviorConsistency,
    required this.integrated,
    required this.weakestLink,
  });
}

class MentalHealthCheckupEngine {
  final MentalHealthCheckupCatalog catalog;

  const MentalHealthCheckupEngine(this.catalog);

  CheckupReport buildReport({
    required String sessionId,
    required String modeId,
    required List<CheckupQuestion> questions,
    required List<CheckupAnswer> answers,
  }) {
    final now = DateTime.now();
    final answerById = <String, CheckupAnswer>{
      for (final answer in answers) answer.questionId: answer,
    };
    final questionById = <String, CheckupQuestion>{
      for (final question in questions) question.id: question,
    };
    final askedSafety = questions.where((e) => e.isSafety).toList();
    final safety = _safetyStatus(askedSafety, answerById);
    final coverage = questions.isEmpty
        ? 0.0
        : answers.where((answer) => questionById.containsKey(answer.questionId)).length /
            questions.length *
            100;
    final functionImpact = _functionImpact(answerById);
    final dataQuality = _dataQuality(answerById, coverage);
    final domainResults = _domainResults(questions, answerById);
    final coveredDomains = domainResults.where((domain) => domain.answered > 0);
    final domainOverall = coveredDomains.isEmpty
        ? 0.0
        : coveredDomains.map((domain) => domain.score).reduce((a, b) => a + b) /
            coveredDomains.length;
    final kab = _kabScores(questions, answerById);
    final overall = kab.integrated ?? domainOverall;
    final uncoveredConcern = (answerById['B20-Q1']?.value ?? 0) > 0;

    final diagnoses = safety == CheckupSafetyStatus.clear
        ? _diagnose(
            questions: questions,
            answers: answerById,
            domains: domainResults,
            overall: overall,
            coverage: coverage,
            dataQuality: dataQuality,
          )
        : const <CheckupDiagnosisResult>[];
    final recommendations = safety == CheckupSafetyStatus.clear
        ? _recommendPrescriptions(
            diagnoses: diagnoses,
            domains: domainResults,
            modeId: modeId,
            coverage: coverage,
          )
        : const <CheckupPrescriptionRecommendation>[];

    final findings = _surfaceFindings(
      safety: safety,
      domains: domainResults,
      functionImpact: functionImpact,
      dataQuality: dataQuality,
      uncoveredConcern: uncoveredConcern,
      answerById: answerById,
      kab: kab,
    );
    final courseEvidenceSet = <String>{
      for (final question in questions)
        if (answerById.containsKey(question.id) &&
            question.evidenceLocation?.isNotEmpty == true)
          '${question.evidenceLocation} · '
              '${question.lecture == null ? '' : 'Lecture ${question.lecture} · '}'
              '${question.indicatorId ?? question.group} · '
              '${question.sourceLevel}',
      for (final domain in domainResults.where((e) => e.answered > 0))
        '${MentalHealthCheckupCatalog.domainLectureAnchors[domain.id]} · ${domain.name}',
      for (final item in recommendations)
        'Lecture ${item.lecture} · ${item.evidenceLocation} · ${item.sourceLevel}',
    };
    final courseEvidence =
        courseEvidenceSet.take(24).toList(growable: false);

    return CheckupReport(
      id: _id('report'),
      sessionId: sessionId,
      modeId: modeId,
      createdAtMs: now.millisecondsSinceEpoch,
      ruleVersion: MentalHealthCheckupCatalog.ruleVersion,
      seedVersion: catalog.validation.version,
      safetyStatus: safety,
      overallScore: _round1(overall),
      knowledgeScore: kab.knowledge == null ? null : _round1(kab.knowledge!),
      attitudeScore: kab.attitude == null ? null : _round1(kab.attitude!),
      behaviorScore: kab.behavior == null ? null : _round1(kab.behavior!),
      attitudeBehaviorConsistency: kab.attitudeBehaviorConsistency == null
          ? null
          : _round1(kab.attitudeBehaviorConsistency!),
      knowledgeBehaviorConsistency: kab.knowledgeBehaviorConsistency == null
          ? null
          : _round1(kab.knowledgeBehaviorConsistency!),
      kabIntegratedScore:
          kab.integrated == null ? null : _round1(kab.integrated!),
      coverage: _round1(coverage.clamp(0, 100)),
      dataQuality: _round1(dataQuality.clamp(0, 100)),
      functionImpact: functionImpact,
      uncoveredConcern: uncoveredConcern,
      domains: domainResults,
      diagnoses: diagnoses,
      prescriptions: recommendations,
      surfaceFindings: findings,
      courseEvidence: courseEvidence,
      sourceBoundaries: const <String>[
        'C1：课程直接内容；可直接支持定义、机制或行动。',
        'C2：课程机制推导；用于候选解释，仍需现实证据验证。',
        'D1：题量、量尺、阈值、剂量和复验期限等产品参数。',
        'D2：安全与功能分流；不进入“课程幸福总分”。',
        '本报告是课程型评估，不是医学疾病诊断、药物处方或治愈承诺。',
      ],
      nextRetestAtMs: recommendations.isEmpty
          ? null
          : now.add(const Duration(days: 7)).millisecondsSinceEpoch,
    );
  }

  CheckupPrescriptionPlan startPlan(
    CheckupReport report,
    CheckupPrescriptionRecommendation recommendation,
  ) {
    final now = DateTime.now();
    return CheckupPrescriptionPlan(
      id: _id('plan'),
      sourceReportId: report.id,
      prescription: recommendation,
      status: CheckupPlanStatus.active,
      doseStage: '微量',
      startedAtMs: now.millisecondsSinceEpoch,
      nextRetestAtMs: report.nextRetestAtMs ??
          now.add(const Duration(days: 7)).millisecondsSinceEpoch,
      logs: const <CheckupExecutionLog>[],
    );
  }

  CheckupRetestRecord evaluateRetest({
    required CheckupPrescriptionPlan plan,
    required CheckupReport baseline,
    required CheckupReport retest,
    List<CheckupRetestRecord> priorRetests =
        const <CheckupRetestRecord>[],
  }) {
    final scoreChange = retest.overallScore - baseline.overallScore;
    final functionChange =
        (baseline.functionImpact - retest.functionImpact).toDouble();
    final executionRate = plan.completionRate;
    final overuse = plan.averageOveruseRisk;
    CheckupRetestRecord? previous;
    for (final item in priorRetests) {
      if (item.planId == plan.id) {
        previous = item;
        break;
      }
    }
    final currentStable = retest.safetyClear &&
        retest.overallScore >= 75 &&
        retest.functionImpact <= 1 &&
        executionRate >= 70 &&
        overuse <= 30;
    final previousStable = previous != null &&
        previous.safetyClear &&
        previous.retestScore >= 75 &&
        previous.retestFunctionImpact <= 1 &&
        previous.executionRate >= 70 &&
        previous.overuseRisk <= 30;
    final currentNoImprovement =
        executionRate >= 70 && scoreChange < 3 && overuse < 50;
    final previousNoImprovement = previous != null &&
        previous.executionRate >= 70 &&
        previous.scoreChange < 3 &&
        previous.overuseRisk < 50;

    String decision;
    String reason;
    if (!retest.safetyClear) {
      decision = '暂停课程任务并进入安全复核';
      reason = '复验安全状态不是 clear，普通课程闭环不能优先处理。';
    } else if (overuse >= 50) {
      decision = '减量或暂停';
      reason = '过度化风险达到 ${overuse.toStringAsFixed(0)}，需先保护现实功能。';
    } else if (currentStable && previousStable) {
      decision = '进入恢复维持';
      reason = '连续两次复验中，目标指标、现实功能、自主执行和过度化制衡达到维持条件。';
    } else if (currentStable) {
      decision = '维持当前剂量';
      reason = '本次复验已达到稳定门槛，但进入恢复维持需要第二次连续稳定证据；'
          '当前不加量，也不因现实功能已处于低影响水平而误判为证据冲突。';
    } else if (scoreChange >= 10 && functionChange > 0) {
      decision = '维持当前剂量';
      reason = '目标改善 ${scoreChange.toStringAsFixed(1)} 分，现实功能也有改善，不宜过早加量。';
    } else if (scoreChange > 0 && functionChange <= 0) {
      decision = '补充功能证据并复核过度化';
      reason = '自评分有所改善，但现实功能尚未同步改善，不能宣布恢复。';
    } else if (executionRate < 50 && overuse < 30) {
      decision = '缩小到微量并调整环境';
      reason = '执行率低首先提示任务难度、时机、环境或恢复不足，而不是意志品质失败。';
    } else if (currentNoImprovement && previousNoImprovement) {
      decision = '重新诊断并考虑换方';
      reason = '连续两个周期在较高执行率下仍没有实质改善，当前机制假设或课程处方可能不匹配。';
    } else if (currentNoImprovement) {
      decision = '保持低剂量并再观察一周期';
      reason = '本周期执行率较高但尚无实质改善；需要第二个周期证据，暂不无限重复或过早换方。';
    } else {
      decision = '继续一周期并保持观察';
      reason = '现有证据不足以支持加量、换方或进入维持，继续收集功能与执行证据。';
    }

    return CheckupRetestRecord(
      id: _id('retest'),
      planId: plan.id,
      baselineReportId: baseline.id,
      retestReportId: retest.id,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      scoreChange: _round1(scoreChange),
      functionChange: _round1(functionChange),
      executionRate: _round1(executionRate),
      overuseRisk: _round1(overuse),
      retestScore: _round1(retest.overallScore),
      retestFunctionImpact: retest.functionImpact,
      safetyClear: retest.safetyClear,
      decision: decision,
      reason: reason,
    );
  }

  CheckupPrescriptionPlan applyRetestDecision(
    CheckupPrescriptionPlan plan,
    CheckupRetestRecord retest,
  ) {
    final next = DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
    if (retest.decision.contains('暂停')) {
      return plan.copyWith(
        status: CheckupPlanStatus.paused,
        nextRetestAtMs: next,
      );
    }
    if (retest.decision == '进入恢复维持') {
      return plan.copyWith(
        status: CheckupPlanStatus.maintenance,
        doseStage: '维持量',
        nextRetestAtMs:
            DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      );
    }
    if (retest.decision == '维持当前剂量') {
      return plan.copyWith(nextRetestAtMs: next);
    }
    if (retest.decision.contains('微量') || retest.decision.contains('减量')) {
      return plan.copyWith(doseStage: '微量', nextRetestAtMs: next);
    }
    return plan.copyWith(nextRetestAtMs: next);
  }

  CheckupSafetyStatus _safetyStatus(
    List<CheckupQuestion> safetyQuestions,
    Map<String, CheckupAnswer> answers,
  ) {
    var uncertain = false;
    for (final question in safetyQuestions) {
      final answer = answers[question.id];
      if (answer == null) {
        if (question.required) uncertain = true;
        continue;
      }
      if (question.id == 'B20-S3') {
        if (answer.value >= 2) return CheckupSafetyStatus.alert;
        if (answer.value >= 1) uncertain = true;
      } else {
        if (answer.value >= 2) return CheckupSafetyStatus.alert;
        if (answer.value >= 1) uncertain = true;
      }
    }
    return uncertain ? CheckupSafetyStatus.uncertain : CheckupSafetyStatus.clear;
  }

  int _functionImpact(Map<String, CheckupAnswer> answers) {
    final f1 = answers['B20-F1']?.value ?? 0;
    final f2 = answers['B20-F2']?.value ?? 0;
    return math.max(f1, f2).round().clamp(0, 4).toInt();
  }

  double _dataQuality(
    Map<String, CheckupAnswer> answers,
    double coverage,
  ) {
    final samples = <double>[];
    final c2 = answers['B20-C2'];
    final q2 = answers['B20-Q2'];
    if (c2 != null) samples.add(c2.value / 4 * 100);
    if (q2 != null) samples.add(q2.value / 4 * 100);
    var quality = samples.isEmpty
        ? coverage * 0.75
        : (samples.reduce((a, b) => a + b) / samples.length) * 0.7 +
            coverage * 0.3;
    final timed =
        answers.values.where((answer) => answer.responseDurationMs > 0).toList();
    if (timed.isNotEmpty) {
      final fastRatio =
          timed.where((answer) => answer.responseDurationMs < 550).length /
              timed.length;
      quality -= fastRatio * 30;
    }
    final ordered = answers.values.toList(growable: false)
      ..sort((a, b) => a.answeredAtMs.compareTo(b.answeredAtMs));
    var longestRun = 0;
    var currentRun = 0;
    double? previous;
    for (final answer in ordered) {
      if (previous == answer.value) {
        currentRun++;
      } else {
        currentRun = 1;
        previous = answer.value;
      }
      longestRun = math.max(longestRun, currentRun);
    }
    if (longestRun >= 8) {
      quality -= 20;
    } else if (longestRun >= 6) {
      quality -= 10;
    }
    final evidence = answers['B20-C2']?.value;
    final authenticity = answers['B20-Q2']?.value;
    if (evidence != null &&
        authenticity != null &&
        (evidence - authenticity).abs() >= 3) {
      quality -= 12;
    }
    return quality.clamp(0, 100).toDouble();
  }

  _KabScores _kabScores(
    List<CheckupQuestion> questions,
    Map<String, CheckupAnswer> answers,
  ) {
    final knowledge = <double>[];
    final attitude = <double>[];
    final behavior = <double>[];
    for (final question in questions) {
      final answer = answers[question.id];
      if (answer == null ||
          question.isSafety ||
          question.isFunction ||
          question.id == 'B20-C2' ||
          question.id.startsWith('B20-Q') ||
          question.id.startsWith('BR-F-')) {
        continue;
      }
      final score = _healthScore(question, answer);
      if (question.isKnowledge) {
        knowledge.add(score);
      } else if (question.id == 'B20-C1' ||
          question.kind.contains('行为') ||
          question.kind == '功能结果') {
        behavior.add(score);
      } else {
        attitude.add(score);
      }
    }
    double? mean(List<double> values) => values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final k = mean(knowledge);
    final a = mean(attitude);
    final b = mean(behavior);
    final integrated =
        k == null || a == null || b == null ? null : k * 0.25 + a * 0.30 + b * 0.45;
    final z = k == null || a == null || b == null
        ? null
        : math.min(k, math.min(a, b)) * 0.6 + ((k + a + b) / 3) * 0.4;
    return _KabScores(
      knowledge: k,
      attitude: a,
      behavior: b,
      attitudeBehaviorConsistency:
          a == null || b == null ? null : 100 - (a - b).abs(),
      knowledgeBehaviorConsistency:
          k == null || b == null ? null : 100 - (k - b).abs(),
      integrated: integrated,
      weakestLink: z,
    );
  }

  List<CheckupDomainResult> _domainResults(
    List<CheckupQuestion> questions,
    Map<String, CheckupAnswer> answers,
  ) {
    return MentalHealthCheckupCatalog.domainNames.entries.map((entry) {
      final domainQuestions =
          questions.where((question) => question.domainId == entry.key).toList();
      final scores = <double>[];
      final indicatorIds = <String>[];
      for (final question in domainQuestions) {
        final answer = answers[question.id];
        if (answer == null) continue;
        scores.add(_healthScore(question, answer));
        if (question.indicatorId != null) indicatorIds.add(question.indicatorId!);
      }
      final score = scores.isEmpty
          ? 0.0
          : scores.reduce((a, b) => a + b) / scores.length;
      return CheckupDomainResult(
        id: entry.key,
        name: entry.value,
        score: _round1(score),
        level: scores.isEmpty ? '未覆盖' : _level(score),
        answered: scores.length,
        expected: domainQuestions.length,
        indicatorIds: indicatorIds,
      );
    }).toList(growable: false);
  }

  double _healthScore(CheckupQuestion question, CheckupAnswer answer) {
    if (question.id == 'B20-K1') return answer.value == 1 ? 100 : 0;
    if (question.id == 'B20-K2') return answer.value == 2 ? 100 : 0;
    final values = question.choices.map((choice) => choice.value).toList();
    final min = values.isEmpty ? 0.0 : values.reduce(math.min);
    final max = values.isEmpty ? 4.0 : values.reduce(math.max);
    final span = math.max(1.0, max - min);
    var normalized = (answer.value - min) / span * 100;
    final reverse = question.direction.contains('风险') ||
        question.direction.contains('差距') ||
        question.kind == '风险型';
    if (reverse) normalized = 100 - normalized;
    return normalized.clamp(0, 100).toDouble();
  }

  List<CheckupDiagnosisResult> _diagnose({
    required List<CheckupQuestion> questions,
    required Map<String, CheckupAnswer> answers,
    required List<CheckupDomainResult> domains,
    required double overall,
    required double coverage,
    required double dataQuality,
  }) {
    final indicatorHealth = <String, double>{};
    for (final question in questions) {
      final indicatorId = question.indicatorId;
      final answer = answers[question.id];
      if (indicatorId == null || answer == null) continue;
      indicatorHealth[indicatorId] = _healthScore(question, answer);
    }
    final domainById = <String, CheckupDomainResult>{
      for (final domain in domains) domain.id: domain,
    };

    final results = <CheckupDiagnosisResult>[];
    for (final pattern in catalog.diagnosisPatterns) {
      if (pattern.id == 'P14') {
        final stable = domains.where((e) => e.answered > 0).length >= 6 &&
            domains.where((e) => e.answered > 0).every((e) => e.score >= 70) &&
            overall >= 75;
        if (!stable) continue;
        final confidence = (65 + (overall - 75) * 1.4).clamp(60, 92).toDouble();
        results.add(CheckupDiagnosisResult(
          patternId: pattern.id,
          name: pattern.name,
          mechanism: pattern.mechanism,
          confidence: _round1(confidence),
          confidenceLevel: _confidenceLevel(confidence),
          candidateOnly: coverage < 75 || pattern.reviewStatus.contains('待'),
          supportingEvidence: <String>[
            '八域中已覆盖领域整体稳定，综合分 ${overall.toStringAsFixed(1)}。',
            '理解、行动、恢复、关系和自尊呈相互支持趋势。',
          ],
          conflictingEvidence: const <String>['短期自评仍需通过后续现实功能与趋势复验。'],
          alternativeHypotheses: const <String>[
            '近期环境顺利造成的暂时上升',
            '回答偏理想化而现实行为证据不足',
          ],
          prescriptionIds: pattern.prescriptionIds,
          reviewStatus: pattern.reviewStatus,
        ));
        continue;
      }

      final triggerScores = <String, double>{
        for (final id in pattern.triggerIndicatorIds)
          if (indicatorHealth.containsKey(id)) id: indicatorHealth[id]!,
      };
      var supporting = triggerScores.entries.where((e) => e.value < 60).toList();
      var conflicting = triggerScores.entries.where((e) => e.value >= 75).toList();
      final fallbackDomains = _fallbackDomainsForPattern(pattern.id);
      if (supporting.isEmpty) {
        for (final domainId in fallbackDomains) {
          final domain = domainById[domainId];
          if (domain != null && domain.answered > 0 && domain.score < 60) {
            supporting = <MapEntry<String, double>>[
              ...supporting,
              MapEntry('领域$domainId', domain.score),
            ];
          }
        }
      }
      if (supporting.isEmpty) continue;

      final averageDeficit = supporting
              .map((e) => 100 - e.value)
              .reduce((a, b) => a + b) /
          supporting.length;
      var confidence = 38 +
          averageDeficit * 0.55 +
          math.min(16, supporting.length * 5) -
          math.min(12, conflicting.length * 3);
      confidence *= 0.62 + coverage.clamp(0, 100) / 100 * 0.25 +
          dataQuality.clamp(0, 100) / 100 * 0.13;
      confidence = confidence.clamp(35, 92).toDouble();

      final candidateOnly = coverage < 75 ||
          confidence < 60 ||
          supporting.length < 2 ||
          pattern.reviewStatus.contains('待');
      results.add(CheckupDiagnosisResult(
        patternId: pattern.id,
        name: pattern.name,
        mechanism: pattern.mechanism,
        confidence: _round1(confidence),
        confidenceLevel: _confidenceLevel(confidence),
        candidateOnly: candidateOnly,
        supportingEvidence: supporting
            .map((entry) =>
                '${_indicatorOrDomainName(entry.key)}健康分 ${entry.value.toStringAsFixed(1)}，低于当前参考带。')
            .toList(growable: false),
        conflictingEvidence: conflicting.isEmpty
            ? const <String>['当前覆盖中尚无强反证；仍需用时间线、功能和行动结果继续检验。']
            : conflicting
                .map((entry) =>
                    '${_indicatorOrDomainName(entry.key)}得分 ${entry.value.toStringAsFixed(1)}，不支持把该模式解释为全面、固定特征。')
                .toList(growable: false),
        alternativeHypotheses: _alternativeHypotheses(pattern.id),
        prescriptionIds: pattern.prescriptionIds,
        reviewStatus: pattern.reviewStatus,
      ));
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.take(3).toList(growable: false);
  }

  List<CheckupPrescriptionRecommendation> _recommendPrescriptions({
    required List<CheckupDiagnosisResult> diagnoses,
    required List<CheckupDomainResult> domains,
    required String modeId,
    required double coverage,
  }) {
    if (coverage < 35 || modeId == 'safety' || modeId == 'daily') {
      return const <CheckupPrescriptionRecommendation>[];
    }
    final candidateIds = <String>[];
    if (diagnoses.isNotEmpty) candidateIds.addAll(diagnoses.first.prescriptionIds);
    if (candidateIds.isEmpty) {
      final covered = domains.where((e) => e.answered > 0).toList()
        ..sort((a, b) => a.score.compareTo(b.score));
      if (covered.isNotEmpty) candidateIds.add(_domainPrescriptionId(covered.first.id));
    }
    for (final id in candidateIds) {
      final item = catalog.prescriptionById(id);
      if (item == null) continue;
      return <CheckupPrescriptionRecommendation>[
        CheckupPrescriptionRecommendation(
          prescriptionId: item.id,
          lecture: item.lecture,
          theme: item.theme,
          target: item.primaryIndicator,
          startingAction: item.startingAction,
          deepeningAction: item.deepeningAction,
          dose: '${item.microDose}；${item.startingDose}',
          trialPeriod: item.trialPeriod,
          evidenceLocation: item.actionLocation,
          sourceLevel: item.sourceLevel,
          stopRule: item.stopRule,
        ),
      ];
    }
    return const <CheckupPrescriptionRecommendation>[];
  }

  List<String> _surfaceFindings({
    required CheckupSafetyStatus safety,
    required List<CheckupDomainResult> domains,
    required int functionImpact,
    required double dataQuality,
    required bool uncoveredConcern,
    required Map<String, CheckupAnswer> answerById,
    required _KabScores kab,
  }) {
    if (safety == CheckupSafetyStatus.alert) {
      return const <String>[
        '安全题出现明确命中：普通课程评分和课程行动处方已暂停。',
        '当前优先级是现实安全、可信任的人和当地专业/紧急支持。',
      ];
    }
    if (safety == CheckupSafetyStatus.uncertain) {
      return const <String>[
        '安全状态存在不确定或轻度异常：本轮不生成普通课程处方。',
        '请先完成更详细安全确认，必要时联系当地专业支持。',
      ];
    }
    final findings = <String>[];
    final covered = domains.where((e) => e.answered > 0).toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    for (final domain in covered.take(3)) {
      findings.add('${domain.name}：${domain.score.toStringAsFixed(1)} 分（${domain.level}）。');
    }
    if (functionImpact >= 2) {
      findings.add('现实功能影响为 $functionImpact/4，结论强度已下调，优先考虑减负、恢复和人工复核。');
    }
    final gap = answerById['B20-C1']?.value ?? 0;
    if (gap >= 2) findings.add('知识认同与现实行动存在明显差距，应优先处理启动、环境、恢复和目标自洽。');
    if (kab.attitude != null &&
        kab.behavior != null &&
        kab.attitude! >= 75 &&
        kab.behavior! < 50) {
      findings.add('态度认同较高但行为证据偏低，优先验证启动门槛、环境和恢复，而不是继续增加知识。');
    }
    if (kab.attitude != null &&
        kab.behavior != null &&
        kab.behavior! >= 75 &&
        kab.attitude! < 50) {
      findings.add('行为完成较高但内在认同偏低，需检查外部驱动、僵化和可持续性。');
    }
    if (kab.weakestLink != null) {
      findings.add('K/A/B薄弱环节整合指数 ${kab.weakestLink!.toStringAsFixed(1)}，用于防止平均分掩盖短板。');
    }
    if (dataQuality < 60) findings.add('回答证据质量或覆盖度有限：以下机制只能视为待验证候选。');
    if (uncoveredConcern) findings.add('你报告了未被题目覆盖的重要变化，应在后续聚焦评估或专业评估中补充。');
    if (findings.isEmpty) findings.add('当前未发现已覆盖领域的明显偏离，仍建议通过纵向复验观察稳定性。');
    return findings;
  }

  String _indicatorOrDomainName(String id) {
    if (id.startsWith('领域')) {
      final domainId = id.substring(2);
      return MentalHealthCheckupCatalog.domainNames[domainId] ?? id;
    }
    final indicator = catalog.indicatorById(id);
    return indicator?.name ?? id;
  }

  static List<String> _fallbackDomainsForPattern(String id) {
    const map = <String, List<String>>{
      'P01': <String>['D3'],
      'P02': <String>['D2', 'D3'],
      'P03': <String>['D1'],
      'P04': <String>['D5', 'D6'],
      'P05': <String>['D3', 'D5'],
      'P06': <String>['D4', 'D5'],
      'P07': <String>['D7', 'D8'],
      'P08': <String>['D1', 'D7'],
      'P09': <String>['D7', 'D8'],
      'P10': <String>['D5', 'D6'],
      'P11': <String>['D3', 'D5'],
      'P12': <String>['D5'],
      'P13': <String>['D1', 'D2', 'D3'],
    };
    return map[id] ?? const <String>[];
  }

  static List<String> _alternativeHypotheses(String patternId) {
    final common = <String>[
      '近期睡眠、身体状态或恢复不足造成的暂时变化',
      '工作、关系或环境的急性变化，而非稳定课程机制',
    ];
    if (patternId == 'P07' || patternId == 'P08' || patternId == 'P09') {
      return <String>[
        '当前关系中的真实安全或权力不对等问题',
        '沟通情境与边界不清，而非固定人格特征',
      ];
    }
    if (patternId == 'P04' || patternId == 'P10') {
      return <String>[
        '需要医学检查的身体或睡眠因素',
        '短期任务高峰或照护负担造成的现实耗竭',
      ];
    }
    return common;
  }

  static String _domainPrescriptionId(String domainId) {
    const map = <String, String>{
      'D1': 'RX-L04',
      'D2': 'RX-L06',
      'D3': 'RX-L11',
      'D4': 'RX-L12',
      'D5': 'RX-L14',
      'D6': 'RX-L18',
      'D7': 'RX-L19',
      'D8': 'RX-L22',
    };
    return map[domainId] ?? 'RX-L01';
  }

  static String _level(double score) {
    if (score >= 75) return '稳定';
    if (score >= 60) return '轻度偏离';
    if (score >= 40) return '需要关注';
    return '明显偏离';
  }

  static String _confidenceLevel(double confidence) {
    if (confidence >= 75) return '高';
    if (confidence >= 60) return '中';
    return '低';
  }

  static double _round1(num value) => double.parse(value.toStringAsFixed(1));

  static String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}
