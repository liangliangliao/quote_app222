import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_catalog.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_engine.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_models.dart';

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

    test('high execution without improvement triggers rediagnosis', () {
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
      expect(retest.decision, contains('重新诊断'));
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
