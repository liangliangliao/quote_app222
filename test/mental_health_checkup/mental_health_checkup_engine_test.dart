import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_backup.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_ai_service.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_catalog.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_engine.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_models.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_trends.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V2.5 seed package', () {
    test('passes hash and row-count validation', () async {
      final catalog = await MentalHealthCheckupCatalog.load();

      expect(catalog.validation.valid, isTrue);
      expect(catalog.validation.checkedFiles, 15);
      expect(catalog.modes, hasLength(7));
      expect(catalog.b20Questions, hasLength(20));
      expect(catalog.indicators, hasLength(345));
      expect(catalog.diagnosisPatterns, hasLength(14));
      expect(catalog.prescriptions, hasLength(23));
      expect(catalog.clinicalTerms, hasLength(10));
      expect(catalog.longitudinalCoverageRules, hasLength(7));
      expect(catalog.branchAlertRules, hasLength(7));
      expect(catalog.aiReportFields, hasLength(17));
      expect(catalog.doseAndCourseRules, hasLength(6));
      expect(catalog.prescriptionAdjustmentRules, hasLength(8));
      expect(catalog.recoveryMaintenanceRules, hasLength(8));
      expect(catalog.sourceBoundaryRules, hasLength(6));
      expect(catalog.seedFieldMappings, hasLength(5));
    });

    test('keeps D1 and D2 supplemental coverage separate', () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      final questions = catalog.questionsForMode(
        'comprehensive',
        now: DateTime(2026, 7, 22),
      );

      expect(questions.where((item) => item.domainId == 'D1'), isNotEmpty);
      expect(questions.where((item) => item.domainId == 'D2'), isNotEmpty);
      expect(
        questions
            .where((item) => item.id.startsWith('IND-') && item.domainId == 'D1')
            .every((item) => item.lecture == 4),
        isTrue,
      );
      expect(
        questions
            .where((item) => item.id.startsWith('IND-') && item.domainId == 'D2')
            .every((item) =>
                item.lecture != null && item.lecture! >= 5 && item.lecture! <= 9),
        isTrue,
      );
    });

    test('focused mode keeps gates unique and includes the focus anchor',
        () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      final questions = catalog.questionsForMode(
        'focused',
        focusDomainId: 'D4',
        now: DateTime(2026, 7, 23),
      );
      final ids = questions.map((item) => item.id).toList(growable: false);

      expect(ids.toSet().length, ids.length);
      expect(ids, contains('B20-D4'));
      expect(ids.where((id) => id == 'B20-S1'), hasLength(1));
    });

    test('low anchors add bounded adaptive evidence questions', () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      final questions =
          catalog.questionsForMode('b20', now: DateTime(2026, 7, 23));
      final anchor = questions.firstWhere((item) => item.id == 'B20-D1');
      final additions = catalog.adaptiveQuestions(
        modeId: 'b20',
        question: anchor,
        answer: _answer(anchor.id, 1),
        existingQuestionIds: questions.map((item) => item.id).toSet(),
        now: DateTime(2026, 7, 23),
      );

      expect(additions, isNotEmpty);
      expect(additions.length, lessThanOrEqualTo(4));
      expect(additions.every((item) => item.domainId == 'D1'), isTrue);
    });

    test('question randomization is repeatable and keeps safety gates first',
        () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      final questions =
          catalog.questionsForMode('standard', now: DateTime(2026, 7, 23));
      final first = catalog.restoreQuestionOrder(
        questions,
        sessionId: 'stable-session',
      );
      final second = catalog.restoreQuestionOrder(
        questions,
        sessionId: 'stable-session',
      );

      expect(
        first.map((item) => item.id),
        orderedEquals(second.map((item) => item.id)),
      );
      expect(first.take(4).every((item) => item.isSafety), isTrue);
    });

    test('assessment plan enforces question limit and uncovered-check choice',
        () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      const plan = CheckupAssessmentPlan(
        timeBudgetMinutes: 15,
        questionLimit: 30,
        includeUncoveredCheck: false,
      );
      final questions = catalog.questionsForMode(
        'focused',
        focusDomainId: 'D1',
        assessmentPlan: plan,
        now: DateTime(2026, 7, 23),
      );

      expect(questions.length, lessThanOrEqualTo(plan.questionLimit));
      expect(questions, isNotEmpty);
      expect(questions.any((question) => question.id == 'B20-Q1'), isFalse);
      expect(questions.take(4).every((question) => question.isSafety), isTrue);
    });

    test('longitudinal selection prioritizes a previously high-risk indicator',
        () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      final anchors =
          catalog.b20Questions.map((question) => question.indicatorId).toSet();
      final target = catalog.indicators.firstWhere(
        (indicator) =>
            indicator.lecture == 4 &&
            indicator.type == '风险型' &&
            !anchors.contains(indicator.id),
      );
      final history = CheckupSession(
        id: 'history',
        modeId: 'focused',
        modeName: '聚焦深入版',
        startedAtMs: DateTime(2026, 5).millisecondsSinceEpoch,
        completedAtMs: DateTime(2026, 5, 1).millisecondsSinceEpoch,
        answers: <CheckupAnswer>[
          _answer('IND-${target.id}', 4),
        ],
        report: _report(
          MentalHealthCheckupEngine(_catalog()),
          'history-report',
          risk: 4,
        ),
      );
      const plan = CheckupAssessmentPlan(
        questionLimit: 70,
        useLongitudinalPrioritization: true,
      );
      final questions = catalog.questionsForMode(
        'focused',
        focusDomainId: 'D1',
        assessmentPlan: plan,
        history: <CheckupSession>[history],
        now: DateTime(2026, 7, 23),
      );
      final prioritized = questions.firstWhere(
        (question) => question.id.startsWith('IND-'),
      );

      expect(prioritized.indicatorId, target.id);
    });
  });

  group('safety-first report engine', () {
    late MentalHealthCheckupEngine engine;
    late List<CheckupQuestion> questions;

    setUp(() {
      engine = MentalHealthCheckupEngine(_catalog());
      questions = _questions();
    });

    test('safety alert blocks ordinary diagnosis and prescription', () {
      final report = engine.buildReport(
        sessionId: 'alert',
        modeId: 'b20',
        questions: questions,
        answers: <CheckupAnswer>[
          _answer('B20-S1', 2),
          _answer('B20-F1', 2),
          _answer('D1-RISK', 4),
        ],
      );

      expect(report.safetyStatus, CheckupSafetyStatus.alert);
      expect(report.diagnoses, isEmpty);
      expect(report.prescriptions, isEmpty);
      expect(report.surfaceFindings.join(), contains('暂停'));
    });

    test('uncertain safety also blocks ordinary course output', () {
      final report = engine.buildReport(
        sessionId: 'uncertain',
        modeId: 'b20',
        questions: questions,
        answers: <CheckupAnswer>[
          _answer('B20-S1', 1),
          _answer('B20-F1', 1),
          _answer('D1-RISK', 3),
        ],
      );

      expect(report.safetyStatus, CheckupSafetyStatus.uncertain);
      expect(report.diagnoses, isEmpty);
      expect(report.prescriptions, isEmpty);
    });

    test('clear safety produces bounded course output', () {
      final report = engine.buildReport(
        sessionId: 'clear',
        modeId: 'b20',
        questions: questions,
        answers: <CheckupAnswer>[
          _answer('B20-S1', 0),
          _answer('B20-F1', 1),
          _answer('D1-RISK', 4),
        ],
      );

      expect(report.safetyStatus, CheckupSafetyStatus.clear);
      expect(report.domains.first.score, 0);
      expect(report.diagnoses.length, lessThanOrEqualTo(3));
      expect(report.prescriptions.length, lessThanOrEqualTo(1));
      expect(report.prescriptions.single.prescriptionId, 'RX-L04');
      expect(report.sourceBoundaries.join(), contains('不是医学疾病诊断'));
    });

    test('user can request assessment-only output without a course action', () {
      final report = engine.buildReport(
        sessionId: 'assessment-only',
        modeId: 'b20',
        questions: questions,
        answers: <CheckupAnswer>[
          _answer('B20-S1', 0),
          _answer('B20-F1', 1),
          _answer('D1-RISK', 4),
        ],
        assessmentPlan: const CheckupAssessmentPlan(
          wantsCourseAction: false,
        ),
      );

      expect(report.diagnoses, isNotEmpty);
      expect(report.prescriptions, isEmpty);
      expect(report.surfaceFindings.join(), contains('只评估'));
    });

    test('K/A/B report uses the documented 25/30/45 weighting', () {
      final kabQuestions = <CheckupQuestion>[
        ...questions.take(2),
        const CheckupQuestion(
          id: 'B20-K1',
          group: '理论',
          kind: '情境判断',
          prompt: '理论题',
          scaleLabel: 'A/B',
          direction: '客观计分',
          sourceLevel: 'C1',
          required: true,
          choices: <CheckupAnswerChoice>[
            CheckupAnswerChoice('A', 0),
            CheckupAnswerChoice('B', 1),
          ],
        ),
        const CheckupQuestion(
          id: 'A1',
          group: '态度',
          kind: '保护型',
          prompt: '态度题',
          scaleLabel: '0-4',
          direction: '越高越健康',
          sourceLevel: 'C2',
          required: true,
          domainId: 'D1',
          choices: <CheckupAnswerChoice>[
            CheckupAnswerChoice('0', 0),
            CheckupAnswerChoice('4', 4),
          ],
        ),
        const CheckupQuestion(
          id: 'B20-C1',
          group: '行为',
          kind: '态度-行为',
          prompt: '差距题',
          scaleLabel: '0-4',
          direction: '越高表示知行差距越大',
          sourceLevel: 'C2',
          required: true,
          choices: <CheckupAnswerChoice>[
            CheckupAnswerChoice('0', 0),
            CheckupAnswerChoice('4', 4),
          ],
        ),
      ];
      final report = engine.buildReport(
        sessionId: 'kab',
        modeId: 'standard',
        questions: kabQuestions,
        answers: <CheckupAnswer>[
          _answer('B20-S1', 0),
          _answer('B20-F1', 0),
          _answer('B20-K1', 1),
          _answer('A1', 4),
          _answer('B20-C1', 4),
        ],
      );

      expect(report.knowledgeScore, 100);
      expect(report.attitudeScore, 100);
      expect(report.behaviorScore, 0);
      expect(report.kabIntegratedScore, 55);
      expect(report.overallScore, 55);
      expect(report.attitudeBehaviorConsistency, 0);
    });
  });

  group('retest adjustment rules', () {
    late MentalHealthCheckupEngine engine;
    late CheckupReport baseline;
    late CheckupReport unchanged;

    setUp(() {
      engine = MentalHealthCheckupEngine(_catalog());
      baseline = _report(engine, 'baseline', risk: 4);
      unchanged = _report(engine, 'unchanged', risk: 4);
    });

    test('one high-execution cycle without improvement waits for evidence', () {
      final plan = _plan(
        baseline,
        <CheckupExecutionLog>[
          _log(completed: true),
          _log(completed: true),
          _log(completed: true),
        ],
      );

      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: unchanged,
      );

      expect(retest.executionRate, 100);
      expect(retest.decision, isNot(contains('重新诊断')));
      expect(retest.decision, contains('再观察一周期'));
    });

    test('two high-execution cycles without improvement trigger rediagnosis',
        () {
      final plan = _plan(
        baseline,
        <CheckupExecutionLog>[
          _log(completed: true),
          _log(completed: true),
          _log(completed: true),
        ],
      );
      final prior = _priorRetest(
        plan: plan,
        baseline: baseline,
        retest: unchanged,
      );

      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: unchanged,
        priorRetests: <CheckupRetestRecord>[prior],
      );

      expect(retest.decision, contains('重新诊断'));
      expect(retest.reason, contains('连续两个周期'));
    });

    test('low execution shrinks the task before blaming the user', () {
      final plan = _plan(
        baseline,
        <CheckupExecutionLog>[
          _log(completed: false),
          _log(completed: false),
        ],
      );

      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: unchanged,
      );

      expect(retest.decision, contains('微量'));
      expect(retest.reason, contains('不是意志品质失败'));
    });

    test('overuse takes priority over score chasing', () {
      final plan = _plan(
        baseline,
        <CheckupExecutionLog>[
          _log(completed: true, overuse: 65),
          _log(completed: true, overuse: 55),
        ],
      );

      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: _report(engine, 'better', risk: 1),
      );

      expect(retest.decision, contains('减量'));
      expect(engine.applyRetestDecision(plan, retest).doseStage, '微量');
    });

    test('maintenance requires two stable retests', () {
      final plan = _plan(
        baseline,
        <CheckupExecutionLog>[
          _log(completed: true),
          _log(completed: true),
          _log(completed: true),
        ],
      );
      final stable = _report(engine, 'stable', risk: 0);
      final first = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: stable,
      );
      expect(first.decision, '维持当前剂量');
      expect(
        engine.applyRetestDecision(plan, first).status,
        CheckupPlanStatus.active,
      );

      final second = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: stable,
        priorRetests: <CheckupRetestRecord>[
          _priorRetest(plan: plan, baseline: baseline, retest: stable),
        ],
      );
      expect(second.decision, '进入恢复维持');
      expect(
        engine.applyRetestDecision(plan, second).status,
        CheckupPlanStatus.maintenance,
      );
    });
  });

  test('persistent state survives a JSON round trip', () {
    final engine = MentalHealthCheckupEngine(_catalog());
    final report = _report(engine, 'roundtrip', risk: 3);
    final session = CheckupSession(
      id: 'session',
      modeId: 'b20',
      modeName: 'B20快速基准',
      startedAtMs: 1,
      completedAtMs: 2,
      answers: <CheckupAnswer>[_answer('B20-S1', 0)],
      report: report,
      assessmentPlan: const CheckupAssessmentPlan(
        timeBudgetMinutes: 10,
        questionLimit: 26,
        wantsCourseAction: false,
      ),
    );
    final state = MentalHealthCheckupState(
      onboardingAccepted: true,
      sessions: <CheckupSession>[session],
    );

    final decoded = MentalHealthCheckupState.decode(state.encode());

    expect(decoded.onboardingAccepted, isTrue);
    expect(decoded.sessions.single.report.id, report.id);
    expect(decoded.sessions.single.report.safetyStatus,
        CheckupSafetyStatus.clear);
    expect(decoded.sessions.single.assessmentPlan.questionLimit, 26);
    expect(decoded.sessions.single.assessmentPlan.wantsCourseAction, isFalse);
  });

  test('full AI context includes the closed loop and excludes local secrets',
      () {
    final catalog = _catalog();
    final engine = MentalHealthCheckupEngine(catalog);
    final report = _report(engine, 'ai-context', risk: 3);
    final session = CheckupSession(
      id: 'ai-session',
      modeId: 'b20',
      modeName: 'B20',
      startedAtMs: 1,
      completedAtMs: 2,
      answers: <CheckupAnswer>[_answer('D1-RISK', 3)],
      report: report,
    );
    final state = MentalHealthCheckupState(
      installId: 'private-install-id',
      settings: const MentalHealthCheckupSettings(
        emergencyNumber: '911-secret',
        crisisNumber: '988-secret',
      ),
      sessions: <CheckupSession>[session],
    );
    final context = MentalHealthCheckupAiService().buildReportContext(
      report: report,
      state: state,
      catalog: catalog,
      includeHistory: true,
    );
    final encoded = jsonEncode(context);

    expect(context, contains('current_report'));
    expect(context, contains('trend_insights'));
    expect(context, contains('plans_and_execution'));
    expect(context, contains('retests'));
    expect(context, contains('governance'));
    expect(encoded, isNot(contains('private-install-id')));
    expect(encoded, isNot(contains('911-secret')));
    expect(encoded, isNot(contains('988-secret')));
  });

  test('backup envelope validates hash and preserves the current install id',
      () {
    final engine = MentalHealthCheckupEngine(_catalog());
    final report = _report(engine, 'backup', risk: 3);
    final session = CheckupSession(
      id: 'backup-session',
      modeId: 'b20',
      modeName: 'B20快速基准',
      startedAtMs: 1,
      completedAtMs: 2,
      answers: <CheckupAnswer>[_answer('B20-S1', 0)],
      report: report,
    );
    final state = MentalHealthCheckupState(
      installId: 'old-install',
      onboardingAccepted: true,
      sessions: <CheckupSession>[session],
    );
    final raw = MentalHealthBackupEnvelope.create(
      state: state,
      seedVersion: 'test',
      now: DateTime.fromMillisecondsSinceEpoch(10),
    );

    final restored = MentalHealthBackupEnvelope.validateAndDecode(
      raw: raw,
      expectedSeedVersion: 'test',
      currentInstallId: 'current-install',
    );

    expect(restored.installId, 'current-install');
    expect(restored.sessions.single.id, session.id);
  });

  test('backup preflight rejects tampered state before persistence', () {
    final raw = MentalHealthBackupEnvelope.create(
      state: const MentalHealthCheckupState(installId: 'source'),
      seedVersion: 'test',
      now: DateTime.fromMillisecondsSinceEpoch(10),
    );
    final root = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final state = Map<String, dynamic>.from(root['state'] as Map);
    state['onboarding_accepted'] = true;
    root['state'] = state;

    expect(
      () => MentalHealthBackupEnvelope.validateAndDecode(
        raw: jsonEncode(root),
        expectedSeedVersion: 'test',
        currentInstallId: 'current',
      ),
      throwsA(isA<MentalHealthBackupException>()),
    );
  });

  test('trend analyzer raises the 15-point personal-baseline rule', () {
    final engine = MentalHealthCheckupEngine(_catalog());
    CheckupSession session(String id, double risk, int completedAt) {
      final report = _report(engine, id, risk: risk);
      return CheckupSession(
        id: id,
        modeId: 'b20',
        modeName: 'B20',
        startedAtMs: completedAt - 1,
        completedAtMs: completedAt,
        answers: const <CheckupAnswer>[],
        report: report,
      );
    }

    final insights = const MentalHealthCheckupTrendAnalyzer().analyze(
      <CheckupSession>[
        session('latest', 4, 3),
        session('prior', 0, 2),
      ],
    );

    expect(insights.any((item) => item.title.contains('个人基线')), isTrue);
  });
}

MentalHealthCheckupCatalog _catalog() => MentalHealthCheckupCatalog(
      modes: const <CheckupModeSpec>[
        CheckupModeSpec(
          id: 'b20',
          name: 'B20快速基准',
          duration: '3-5分钟',
          baseQuestionCount: 20,
          maxQuestionCount: 20,
          fixedContent: '安全门、功能门、八域',
          actionCount: '最多1项',
          useCase: '快速基准',
          coverageLevel: '中',
        ),
      ],
      b20Questions: _questions(),
      indicators: const <CheckupIndicator>[
        CheckupIndicator(
          id: 'I1',
          lecture: 4,
          area: '情绪与认知',
          name: '情绪接纳',
          type: '风险型',
          definitionLocation: 'L04-P001',
          lowLocation: 'L04-P002',
          highLocation: 'L04-P003',
          actionLocation: 'L04-P004',
          directEvidenceCount: 3,
          directness: '直接证据较强',
          reviewStatus: '待课程专家确认',
        ),
      ],
      diagnosisPatterns: const <CheckupDiagnosisPattern>[
        CheckupDiagnosisPattern(
          id: 'P03',
          name: '情绪抵抗循环候选',
          triggerIndicatorIds: <String>['I1'],
          mechanism: '抵抗情绪可能放大消耗。',
          prescriptionIds: <String>['RX-L04'],
          priorityAction: '允许情绪并选择小行动',
          evidenceNeeded: '情绪、行为和功能证据',
          exclusions: '睡眠、环境与身体因素',
          confidenceRule: '两类证据以上',
          reviewStatus: '待课程专家确认',
        ),
      ],
      prescriptions: const <CheckupPrescription>[
        CheckupPrescription(
          id: 'RX-L04',
          lecture: 4,
          theme: '允许情绪存在',
          primaryIndicatorId: 'I1',
          primaryIndicator: '情绪接纳',
          actionLocation: 'L04-P004',
          mechanism: '减少情绪抵抗',
          startingAction: '命名情绪，并完成一个安全的小行动。',
          deepeningAction: '记录情绪与行动的关系。',
          microDose: '1分钟',
          startingDose: '每日1次',
          consolidationDose: '每周3次',
          trialPeriod: '7天',
          outcomeEvidence: '功能与自主性',
          stopRule: '若明显加重痛苦或影响现实功能则暂停。',
          sourceLevel: 'C1+D1',
          reviewStatus: '待课程专家确认',
        ),
      ],
      validation: const CheckupSeedValidationResult(
        valid: true,
        version: 'test',
        checkedFiles: 0,
        errors: <String>[],
      ),
    );

List<CheckupQuestion> _questions() => const <CheckupQuestion>[
      CheckupQuestion(
        id: 'B20-S1',
        group: '安全门',
        kind: '分流',
        prompt: '是否存在立即危险？',
        scaleLabel: '否/不确定/是',
        direction: 'D2安全分流',
        sourceLevel: 'D2',
        required: true,
        choices: <CheckupAnswerChoice>[
          CheckupAnswerChoice('否', 0),
          CheckupAnswerChoice('不确定', 1),
          CheckupAnswerChoice('是', 2),
        ],
      ),
      CheckupQuestion(
        id: 'B20-F1',
        group: '功能门',
        kind: '功能',
        prompt: '现实功能影响？',
        scaleLabel: '0-4',
        direction: '越高风险越高',
        sourceLevel: 'D2',
        required: true,
        choices: <CheckupAnswerChoice>[
          CheckupAnswerChoice('0', 0),
          CheckupAnswerChoice('1', 1),
          CheckupAnswerChoice('2', 2),
          CheckupAnswerChoice('3', 3),
          CheckupAnswerChoice('4', 4),
        ],
      ),
      CheckupQuestion(
        id: 'D1-RISK',
        group: '八域',
        kind: '风险型',
        prompt: '情绪抵抗程度？',
        scaleLabel: '0-4',
        direction: '越高风险越高',
        sourceLevel: 'C1',
        required: true,
        indicatorId: 'I1',
        domainId: 'D1',
        lecture: 4,
        evidenceLocation: 'L04-P001',
        choices: <CheckupAnswerChoice>[
          CheckupAnswerChoice('0', 0),
          CheckupAnswerChoice('1', 1),
          CheckupAnswerChoice('2', 2),
          CheckupAnswerChoice('3', 3),
          CheckupAnswerChoice('4', 4),
        ],
      ),
    ];

CheckupAnswer _answer(String id, double value) => CheckupAnswer(
      questionId: id,
      label: value.toString(),
      value: value,
      answeredAtMs: 1,
    );

CheckupReport _report(
  MentalHealthCheckupEngine engine,
  String id, {
  required double risk,
}) =>
    engine.buildReport(
      sessionId: id,
      modeId: 'b20',
      questions: _questions(),
      answers: <CheckupAnswer>[
        _answer('B20-S1', 0),
        _answer('B20-F1', 1),
        _answer('D1-RISK', risk),
      ],
    );

CheckupPrescriptionPlan _plan(
  CheckupReport report,
  List<CheckupExecutionLog> logs,
) =>
    CheckupPrescriptionPlan(
      id: 'plan',
      sourceReportId: report.id,
      prescription: report.prescriptions.single,
      status: CheckupPlanStatus.active,
      doseStage: '微量',
      startedAtMs: 1,
      nextRetestAtMs: 2,
      logs: logs,
    );

CheckupExecutionLog _log({
  required bool completed,
  double overuse = 0,
}) =>
    CheckupExecutionLog(
      createdAtMs: 1,
      completed: completed,
      effort: 3,
      benefit: 4,
      functionChange: 0,
      overuseRisk: overuse,
    );

CheckupRetestRecord _priorRetest({
  required CheckupPrescriptionPlan plan,
  required CheckupReport baseline,
  required CheckupReport retest,
}) =>
    CheckupRetestRecord(
      id: 'prior',
      planId: plan.id,
      baselineReportId: baseline.id,
      retestReportId: retest.id,
      createdAtMs: 1,
      scoreChange: retest.overallScore - baseline.overallScore,
      functionChange:
          (baseline.functionImpact - retest.functionImpact).toDouble(),
      executionRate: plan.completionRate,
      overuseRisk: plan.averageOveruseRisk,
      retestScore: retest.overallScore,
      retestFunctionImpact: retest.functionImpact,
      safetyClear: retest.safetyClear,
      decision: '保持低剂量并再观察一周期',
      reason: '第一周期证据。',
    );
