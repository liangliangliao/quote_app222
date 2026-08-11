import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/mental_health_checkup/mental_health_content_governance.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_backup.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_ai_service.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_catalog.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_engine.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_models.dart';
import 'package:quote_app/mental_health_checkup/mental_health_checkup_trends.dart';
import 'package:quote_app/mental_health_checkup/mental_health_generation_batch.dart';
import 'package:quote_app/mental_health_checkup/mental_health_indicator_governance.dart';
import 'package:quote_app/mental_health_checkup/mental_health_knowledge_models.dart';
import 'package:quote_app/mental_health_checkup/mental_health_validation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V2.5 seed package', () {
    test('passes hash and row-count validation', () async {
      final catalog = await MentalHealthCheckupCatalog.load();

      expect(catalog.validation.valid, isTrue);
      expect(catalog.validation.checkedFiles, 16);
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
      expect(catalog.legacyContentCandidates, hasLength(138));
      expect(
        catalog.legacyContentCandidates.where(
          (candidate) => candidate.kind == CheckupContentKind.assessmentItem,
        ),
        hasLength(92),
      );
      expect(
        catalog.legacyContentCandidates.where(
          (candidate) => candidate.kind == CheckupContentKind.behaviorTask,
        ),
        hasLength(46),
      );
      expect(
        catalog.legacyContentCandidates.every(
          (candidate) =>
              candidate.stage == CheckupCandidateStage.candidate &&
              candidate.reviewer.isEmpty &&
              candidate.signer.isEmpty,
        ),
        isTrue,
      );
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
            .where(
              (item) => item.id.startsWith('IND-') && item.domainId == 'D1',
            )
            .every((item) => item.lecture == 4),
        isTrue,
      );
      expect(
        questions
            .where(
              (item) => item.id.startsWith('IND-') && item.domainId == 'D2',
            )
            .every(
              (item) =>
                  item.lecture != null &&
                  item.lecture! >= 5 &&
                  item.lecture! <= 9,
            ),
        isTrue,
      );
    });

    test(
      'only fully signed official items enter the rotating assessment bank',
      () async {
        final seed = await MentalHealthCheckupCatalog.load();
        final anchors =
            seed.b20Questions.map((question) => question.indicatorId).toSet();
        final indicator = seed.indicators.firstWhere(
          (value) =>
              value.lecture == 4 &&
              !value.id.contains('-K') &&
              !anchors.contains(value.id),
        );
        final official = _officialContent(
          candidateId: 'OFFICIAL-${indicator.id}-A3',
          indicator: indicator,
          contentCode: 'A3',
        );
        final catalog = seed.withPublishedContent(<CheckupContentCandidate>[
          official.copyWith(
            candidateId: 'UNSIGNED-${indicator.id}-A3',
            stage: CheckupCandidateStage.candidate,
            signer: '',
          ),
          official,
        ]);
        final questions = catalog.questionsForMode(
          'focused',
          focusDomainId: 'D1',
          assessmentPlan: const CheckupAssessmentPlan(questionLimit: 70),
          now: DateTime(2026, 7, 25),
        );

        expect(catalog.publishedContentCandidates, hasLength(1));
        expect(catalog.publishedQuestions, hasLength(1));
        expect(
          questions.any(
            (question) =>
                question.contentCandidateId == official.candidateId &&
                question.id == 'PUB-${official.candidateId}',
          ),
          isTrue,
        );
      },
    );

    test(
      'official A7 uses its signed answer key and preserves item version',
      () {
        const indicator = CheckupIndicator(
          id: 'L04-K9',
          lecture: 4,
          area: '情绪与认知',
          name: '情绪接纳理论迁移',
          type: '核心理论',
          definitionLocation: 'L04-P001',
          lowLocation: 'L04-P002',
          highLocation: 'L04-P003',
          actionLocation: 'L04-P004',
          directEvidenceCount: 3,
          directness: '直接证据较强',
          reviewStatus: '已确认',
        );
        final official = _officialContent(
          candidateId: 'OFFICIAL-L04-K9-A7',
          indicator: indicator,
          contentCode: 'A7',
          answerOptions: const <String>['回避所有感受', '接纳感受并选择安全行动', '只重复口号'],
          correctAnswerIndex: 1,
        );
        final base = _catalogWithIndicator(indicator);
        final catalog = base.withPublishedContent(<CheckupContentCandidate>[
          official,
        ]);
        final question = catalog.publishedQuestions.single;
        final report = MentalHealthCheckupEngine(catalog).buildReport(
          sessionId: 'published-a7',
          modeId: 'standard',
          questions: <CheckupQuestion>[..._questions().take(2), question],
          answers: <CheckupAnswer>[
            _answer('B20-S1', 0),
            _answer('B20-F1', 0),
            _answer(question.id, 1),
          ],
        );

        expect(question.isKnowledge, isTrue);
        expect(question.correctChoiceValue, 1);
        expect(question.contentVersion, 1);
        expect(report.knowledgeScore, 100);
        expect(report.domains.first.score, 100);
      },
    );

    test(
      'retired signed items only restore an existing draft snapshot',
      () async {
        final seed = await MentalHealthCheckupCatalog.load();
        final anchors =
            seed.b20Questions.map((question) => question.indicatorId).toSet();
        final indicator = seed.indicators.firstWhere(
          (value) =>
              value.lecture == 4 &&
              !value.id.contains('-K') &&
              !anchors.contains(value.id),
        );
        final retired = _officialContent(
          candidateId: 'RETIRED-${indicator.id}-A3',
          indicator: indicator,
          contentCode: 'A3',
        ).copyWith(
          stage: CheckupCandidateStage.retired,
          retirementReason: '已有更高版本。',
        );
        final catalog = seed.withPublishedContent(<CheckupContentCandidate>[
          retired,
        ]);
        final fresh = catalog.questionsForMode(
          'focused',
          focusDomainId: 'D1',
          assessmentPlan: const CheckupAssessmentPlan(questionLimit: 70),
          now: DateTime(2026, 7, 25),
        );
        final retiredId = 'PUB-${retired.candidateId}';
        final restored = catalog.restoreQuestionOrder(
          fresh,
          sessionId: 'draft-with-retired-question',
          storedQuestionIds: <String>[retiredId],
        );

        expect(fresh.any((question) => question.id == retiredId), isFalse);
        expect(restored.first.id, retiredId);
        expect(restored.first.retiredSnapshot, isTrue);
        expect(catalog.publishedQuestions, isEmpty);
        expect(catalog.retiredPublishedQuestions, hasLength(1));
      },
    );

    test(
      'focused mode keeps gates unique and includes the focus anchor',
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
      },
    );

    test('low anchors add bounded adaptive evidence questions', () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      final questions = catalog.questionsForMode(
        'b20',
        now: DateTime(2026, 7, 23),
      );
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

    test(
      'question randomization is repeatable and keeps safety gates first',
      () async {
        final catalog = await MentalHealthCheckupCatalog.load();
        final questions = catalog.questionsForMode(
          'standard',
          now: DateTime(2026, 7, 23),
        );
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
      },
    );

    test(
      'assessment plan enforces question limit and uncovered-check choice',
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
        expect(
          questions.take(4).every((question) => question.isSafety),
          isTrue,
        );
      },
    );

    test(
      'longitudinal selection prioritizes a previously high-risk indicator',
      () async {
        final catalog = await MentalHealthCheckupCatalog.load();
        final anchors = catalog.b20Questions
            .map((question) => question.indicatorId)
            .toSet();
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
          answers: <CheckupAnswer>[_answer('IND-${target.id}', 4)],
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
      },
    );
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

    test('official B1 replaces the matching starter task and is versioned', () {
      final indicator = _catalog().indicators.single;
      final task = _officialContent(
        candidateId: 'OFFICIAL-I1-B1',
        indicator: indicator,
        contentCode: 'B1',
        kind: CheckupContentKind.behaviorTask,
        content: '用30秒记录情绪，并完成一个不会扩大风险的安全小行动。',
      );
      final catalog = _catalog().withPublishedContent(<CheckupContentCandidate>[
        task,
      ]);
      final report = MentalHealthCheckupEngine(catalog).buildReport(
        sessionId: 'published-task',
        modeId: 'b20',
        questions: _questions(),
        answers: <CheckupAnswer>[
          _answer('B20-S1', 0),
          _answer('B20-F1', 1),
          _answer('D1-RISK', 4),
        ],
      );
      final recommendation = report.prescriptions.single;
      final restored = CheckupReport.fromJson(
        Map<String, dynamic>.from(report.toJson()),
      ).prescriptions.single;

      expect(recommendation.startingAction, task.content);
      expect(recommendation.contentCandidateId, task.candidateId);
      expect(recommendation.contentVersion, task.version);
      expect(restored.contentCandidateId, task.candidateId);
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
        assessmentPlan: const CheckupAssessmentPlan(wantsCourseAction: false),
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
      final plan = _plan(baseline, <CheckupExecutionLog>[
        _log(completed: true),
        _log(completed: true),
        _log(completed: true),
      ]);

      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: unchanged,
      );

      expect(retest.executionRate, 100);
      expect(retest.decision, isNot(contains('重新诊断')));
      expect(retest.decision, contains('再观察一周期'));
    });

    test(
      'two high-execution cycles without improvement trigger rediagnosis',
      () {
        final plan = _plan(baseline, <CheckupExecutionLog>[
          _log(completed: true),
          _log(completed: true),
          _log(completed: true),
        ]);
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
      },
    );

    test('low execution shrinks the task before blaming the user', () {
      final plan = _plan(baseline, <CheckupExecutionLog>[
        _log(completed: false),
        _log(completed: false),
      ]);

      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: unchanged,
      );

      expect(retest.decision, contains('微量'));
      expect(retest.reason, contains('不是意志品质失败'));
    });

    test('overuse takes priority over score chasing', () {
      final plan = _plan(baseline, <CheckupExecutionLog>[
        _log(completed: true, overuse: 65),
        _log(completed: true, overuse: 55),
      ]);

      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: _report(engine, 'better', risk: 1),
      );

      expect(retest.decision, contains('减量'));
      expect(engine.applyRetestDecision(plan, retest).doseStage, '微量');
    });

    test('maintenance requires two stable retests', () {
      final plan = _plan(baseline, <CheckupExecutionLog>[
        _log(completed: true),
        _log(completed: true),
        _log(completed: true),
      ]);
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

    test('recovery is blocked without autonomy and a relapse plan', () {
      final plan = _plan(baseline, <CheckupExecutionLog>[
        _log(completed: true, autonomy: 4, relapsePlanReady: false),
        _log(completed: true, autonomy: 5, relapsePlanReady: false),
      ]);
      final stable = _report(engine, 'stable-without-autonomy', risk: 0);
      final retest = engine.evaluateRetest(
        plan: plan,
        baseline: baseline,
        retest: stable,
        priorRetests: <CheckupRetestRecord>[
          _priorRetest(plan: plan, baseline: baseline, retest: stable),
        ],
      );

      expect(retest.decision, contains('自主执行'));
      expect(retest.reason, contains('暂不宣布'));
      expect(retest.autonomyScore, 45);
      expect(retest.relapsePlanReady, isFalse);
      final restored = CheckupRetestRecord.fromJson(
        Map<String, dynamic>.from(retest.toJson()),
      );
      expect(restored.autonomyScore, 45);
      expect(restored.relapsePlanReady, isFalse);
      expect(
        engine.applyRetestDecision(plan, retest).status,
        CheckupPlanStatus.active,
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
      settings: const MentalHealthCheckupSettings(appLockEnabled: true),
      sessions: <CheckupSession>[session],
    );

    final decoded = MentalHealthCheckupState.decode(state.encode());

    expect(decoded.onboardingAccepted, isTrue);
    expect(decoded.sessions.single.report.id, report.id);
    expect(
      decoded.sessions.single.report.safetyStatus,
      CheckupSafetyStatus.clear,
    );
    expect(decoded.sessions.single.assessmentPlan.questionLimit, 26);
    expect(decoded.sessions.single.assessmentPlan.wantsCourseAction, isFalse);
    expect(decoded.settings.appLockEnabled, isTrue);
  });

  test('external AI prompt layers cannot receive personal checkup data', () {
    expect(
      MentalHealthCheckupPromptConfig.labels.keys,
      containsAll(<String>[
        MentalHealthCheckupPromptConfig.globalId,
        MentalHealthCheckupPromptConfig.contentCandidateId,
        MentalHealthCheckupPromptConfig.indicatorCandidateId,
      ]),
    );
    expect(MentalHealthCheckupPromptConfig.labels, hasLength(3));
    expect(
      MentalHealthCheckupPromptConfig.defaultGlobalPrompt,
      contains('不能接收或推断任何用户的回答、报告、行动记录、复验记录'),
    );
    expect(
      MentalHealthCheckupPromptConfig.defaultGlobalPrompt,
      contains('报告和复验解释必须由本机规则完成'),
    );
  });

  test(
    'backup envelope validates hash and preserves the current install id',
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
    },
  );

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
      <CheckupSession>[session('latest', 4, 3), session('prior', 0, 2)],
    );

    expect(insights.any((item) => item.title.contains('个人基线')), isTrue);
  });

  group('content candidate governance', () {
    const governance = MentalHealthContentGovernanceEngine();
    const indicators = <CheckupIndicator>[
      CheckupIndicator(
        id: 'L04-C1',
        lecture: 4,
        area: '情绪与认知',
        name: '情绪接纳',
        type: '保护型',
        definitionLocation: 'L04-P001',
        lowLocation: 'L04-P002',
        highLocation: 'L04-P003',
        actionLocation: 'L04-P004',
        directEvidenceCount: 4,
        directness: '直接证据较强',
        reviewStatus: '待课程专家确认',
      ),
      CheckupIndicator(
        id: 'L04-R1',
        lecture: 4,
        area: '情绪与认知',
        name: '强迫积极',
        type: '风险型',
        definitionLocation: 'L04-P010',
        lowLocation: 'L04-P011',
        highLocation: 'L04-P012',
        actionLocation: 'L04-P013',
        directEvidenceCount: 2,
        directness: '混合直接/推导',
        reviewStatus: '待课程专家确认',
      ),
    ];

    test('every indicator gets item types, B0-B4 and evidence ids', () {
      final queue = governance.buildGenerationQueue(indicators);

      expect(queue, hasLength(indicators.length));
      expect(
        queue.every(
          (plan) => plan.behaviorLevels.toSet().containsAll(const <String>{
            'B0',
            'B1',
            'B2',
            'B3',
            'B4',
          }),
        ),
        isTrue,
      );
      expect(queue.every((plan) => plan.itemTypeCodes.length >= 4), isTrue);
      expect(queue.every((plan) => plan.evidenceIds.isNotEmpty), isTrue);
      expect(
        queue.firstWhere((plan) => plan.indicatorId == 'L04-R1').itemTypeCodes,
        containsAll(const <String>['A5', 'A3', 'A4', 'A8']),
      );
    });

    test('quality gate rejects an unreviewed local template', () {
      final plan = governance.buildGenerationQueue(indicators).first;
      final draft = governance.createLocalDraft(
        plan: plan,
        contentCode: 'A3',
        courseVersion: '2.5',
        now: DateTime.fromMillisecondsSinceEpoch(100),
      );

      final validation = governance.validate(draft);
      expect(validation.valid, isFalse);
      expect(
        validation.blockingIssues.any((issue) => issue.contains('课程忠实度')),
        isTrue,
      );
      expect(
        () => governance.transition(
          candidate: draft,
          target: CheckupCandidateStage.candidate,
          actor: '作者甲',
          note: '提交候选',
        ),
        throwsStateError,
      );
    });

    test(
      'independent review, interview and pilot are required for publish',
      () {
        final plan = governance.buildGenerationQueue(indicators).first;
        var value = governance.createLocalDraft(
          plan: plan,
          contentCode: 'A3',
          courseVersion: '2.5',
          author: '作者甲',
          now: DateTime.fromMillisecondsSinceEpoch(100),
        );
        value = value.copyWith(
          quality: const CheckupCandidateQuality(
            indicatorConsistency: 90,
            courseFidelity: 90,
            nonDuplication: 90,
            measurability: 90,
            scaleWindowFit: 90,
            bidirectionalLogic: 90,
            safety: 95,
          ),
        );
        value = governance
            .transition(
              candidate: value,
              target: CheckupCandidateStage.candidate,
              actor: '作者甲',
              note: '字段与质量门通过',
              now: DateTime.fromMillisecondsSinceEpoch(101),
            )
            .candidate
            .copyWith(evidenceReviewPassed: true, constructReviewPassed: true);

        expect(
          () => governance.transition(
            candidate: value,
            target: CheckupCandidateStage.cognitiveInterview,
            actor: '作者甲',
            note: '自行审核',
          ),
          throwsStateError,
        );

        value = governance
            .transition(
              candidate: value,
              target: CheckupCandidateStage.cognitiveInterview,
              actor: '独立审核乙',
              note: '课程证据与单一构念通过',
              now: DateTime.fromMillisecondsSinceEpoch(102),
            )
            .candidate;
        expect(
          () => governance.transition(
            candidate: value,
            target: CheckupCandidateStage.pilot,
            actor: '访谈员丙',
            note: '尚未访谈',
          ),
          throwsStateError,
        );

        value = value.copyWith(cognitiveInterviewPassed: true);
        value = governance
            .transition(
              candidate: value,
              target: CheckupCandidateStage.pilot,
              actor: '访谈员丙',
              note: '目标用户理解符合预期',
              now: DateTime.fromMillisecondsSinceEpoch(103),
            )
            .candidate
            .copyWith(
              pilotPassed: true,
              pilotSampleSize: 24,
              pilotNotes: '缺失率、区分度和初步稳定性达到预设门槛。',
            );

        expect(
          () => governance.transition(
            candidate: value,
            target: CheckupCandidateStage.official,
            actor: 'AI审核',
            note: '自动发布',
          ),
          throwsStateError,
        );
        final published = governance.transition(
          candidate: value,
          target: CheckupCandidateStage.official,
          actor: '签发人丁',
          note: '人工签发V1',
          now: DateTime.fromMillisecondsSinceEpoch(104),
        );
        expect(published.candidate.stage, CheckupCandidateStage.official);
        expect(published.candidate.signer, '签发人丁');
        expect(published.auditEvent.fromStage, CheckupCandidateStage.pilot);
      },
    );

    test('official content creates a new immutable revision lineage', () {
      final plan = governance.buildGenerationQueue(indicators).first;
      final official = governance
          .createLocalDraft(
            plan: plan,
            contentCode: 'B1',
            courseVersion: '2.5',
            now: DateTime.fromMillisecondsSinceEpoch(100),
          )
          .copyWith(
            stage: CheckupCandidateStage.official,
            version: 3,
            signer: '签发人',
          );

      final revision = governance.reviseOfficial(
        official: official,
        author: '修订者',
        now: DateTime.fromMillisecondsSinceEpoch(200),
      );

      expect(revision.stage, CheckupCandidateStage.draft);
      expect(revision.version, 4);
      expect(revision.parentCandidateId, official.candidateId);
      expect(official.stage, CheckupCandidateStage.official);
      expect(official.version, 3);
    });

    test('candidate JSON keeps version and audit-critical fields', () {
      final plan = governance.buildGenerationQueue(indicators).last;
      final value = governance.createLocalDraft(
        plan: plan,
        contentCode: 'B2',
        courseVersion: '2.5',
        now: DateTime.fromMillisecondsSinceEpoch(100),
      );
      final restored = CheckupContentCandidate.fromJson(
        Map<String, dynamic>.from(value.toJson()),
      );

      expect(restored.candidateId, value.candidateId);
      expect(restored.primaryIndicatorId, 'L04-R1');
      expect(restored.courseEvidenceIds, value.courseEvidenceIds);
      expect(restored.smallerVersion, isNotEmpty);
      expect(restored.counterEvidencePrompt, isNotEmpty);
      expect(restored.safetyRule, contains('不得练习风险行为'));
    });
  });

  group('full content blueprints and human validation evidence', () {
    test('materializes exactly nine stable slots for all 345 indicators',
        () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      const factory = MentalHealthContentBlueprintFactory();

      final first = factory.build(
        catalog.indicators,
        courseVersion: catalog.validation.version,
      );
      final second = factory.build(
        catalog.indicators,
        courseVersion: catalog.validation.version,
      );
      final ids = first.map((candidate) => candidate.candidateId).toSet();
      final counts = <String, int>{};
      for (final candidate in first) {
        counts.update(
          candidate.primaryIndicatorId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      expect(
        first,
        hasLength(MentalHealthContentBlueprintFactory.expectedCandidateCount),
      );
      expect(ids, hasLength(first.length));
      expect(counts, hasLength(345));
      expect(counts.values.every((count) => count == 9), isTrue);
      expect(first.map((value) => value.toJson()).toList(), second.map((value) => value.toJson()).toList());
      expect(
        first.every(
          (candidate) =>
              candidate.stage == CheckupCandidateStage.draft &&
              candidate.courseEvidenceIds.isNotEmpty &&
              candidate.content.trim().isNotEmpty &&
              candidate.safetyRule.trim().isNotEmpty,
        ),
        isTrue,
      );
      expect(
        first
            .where((candidate) => candidate.kind == CheckupContentKind.behaviorTask)
            .map((candidate) => candidate.contentCode)
            .toSet(),
        containsAll(const <String>['B0', 'B1', 'B2', 'B3', 'B4']),
      );
    });

    test('real records drive all validation gates and content edits invalidate them',
        () async {
      final catalog = await MentalHealthCheckupCatalog.load();
      final candidate = const MentalHealthContentBlueprintFactory()
          .build(
            catalog.indicators,
            courseVersion: catalog.validation.version,
          )
          .firstWhere(
            (value) =>
                value.contentCode == 'A3' &&
                !value.indicatorType.contains('风险'),
          );
      final fingerprint =
          MentalHealthValidationEngine.candidateFingerprint(candidate);
      const quality = CheckupCandidateQuality(
        indicatorConsistency: 90,
        courseFidelity: 90,
        nonDuplication: 90,
        measurability: 90,
        scaleWindowFit: 90,
        bidirectionalLogic: 90,
        safety: 95,
      );
      final reviews = <CheckupExpertReviewRecord>[
        CheckupExpertReviewRecord(
          id: 'course-review',
          candidateId: candidate.candidateId,
          candidateFingerprint: fingerprint,
          reviewerId: 'course-expert-01',
          role: CheckupExpertReviewRole.courseExpert,
          quality: quality,
          passed: true,
          note: '课程证据逐条核对通过',
          createdAtMs: 1,
        ),
        CheckupExpertReviewRecord(
          id: 'measurement-review',
          candidateId: candidate.candidateId,
          candidateFingerprint: fingerprint,
          reviewerId: 'measurement-reviewer-02',
          role: CheckupExpertReviewRole.measurementReviewer,
          quality: quality,
          passed: true,
          note: '单一构念与量尺通过',
          createdAtMs: 2,
        ),
      ];
      final interviews = List<CheckupCognitiveInterviewRecord>.generate(
        5,
        (index) => CheckupCognitiveInterviewRecord(
          id: 'cognitive-$index',
          candidateId: candidate.candidateId,
          candidateFingerprint: fingerprint,
          participantKey: MentalHealthValidationEngine.participantKey(
            studySalt: 'cognitive-study-salt',
            localAlias: 'participant-$index',
          ),
          understoodConstruct: true,
          understoodRecallWindow: true,
          optionsClear: true,
          doubleBarrelDetected: false,
          leadingLanguageDetected: false,
          burdenAcceptable: true,
          note: '',
          createdAtMs: 10 + index,
        ),
      );
      final observations = List<CheckupPilotObservation>.generate(
        30,
        (index) {
          final score = (index % 5).toDouble();
          return CheckupPilotObservation(
            id: 'pilot-$index',
            candidateId: candidate.candidateId,
            candidateFingerprint: fingerprint,
            participantKey: MentalHealthValidationEngine.participantKey(
              studySalt: 'pilot-study-salt',
              localAlias: 'participant-$index',
            ),
            missing: false,
            completionTimeMs: 30000,
            itemScore: score,
            restScore: score * 2 + 1,
            retestScore: score,
            behaviorCriterion: score,
            fairnessGroup: index < 15 ? 'group-a' : 'group-b',
            createdAtMs: 100 + index,
          );
        },
      );
      const engine = MentalHealthValidationEngine();
      final dossier = CheckupValidationDossier(
        expertReviews: reviews,
        cognitiveInterviews: interviews,
        pilotObservations: observations,
      );

      final decision = engine.evaluate(
        candidate: candidate,
        dossier: dossier,
      );
      final synchronized = engine.applyDecision(
        candidate: candidate,
        decision: decision,
        now: DateTime.fromMillisecondsSinceEpoch(999),
      );

      expect(decision.blockingIssues, isEmpty);
      expect(decision.readyForHumanSignature, isTrue);
      expect(decision.cognitiveSampleSize, 5);
      expect(decision.pilotSampleSize, 30);
      expect(decision.metrics['item_rest_correlation'], closeTo(1, 0.0001));
      expect(synchronized.evidenceReviewPassed, isTrue);
      expect(synchronized.constructReviewPassed, isTrue);
      expect(synchronized.cognitiveInterviewPassed, isTrue);
      expect(synchronized.pilotPassed, isTrue);

      final edited = candidate.copyWith(content: '${candidate.content}（修订）');
      final editedDecision = engine.evaluate(
        candidate: edited,
        dossier: dossier,
      );
      expect(editedDecision.readyForHumanSignature, isFalse);
      expect(
        editedDecision.warnings.any((warning) => warning.contains('内容指纹')),
        isTrue,
      );
      expect(
        editedDecision.blockingIssues,
        contains('缺少通过的课程专家证据审核'),
      );
    });

    test('validation package detects tampering and participant keys are private',
        () {
      const indicator = CheckupIndicator(
        id: 'L04-C1',
        lecture: 4,
        area: '情绪与认知',
        name: '情绪接纳',
        type: '保护型',
        definitionLocation: 'L04-P001',
        lowLocation: 'L04-P002',
        highLocation: 'L04-P003',
        actionLocation: 'L04-P004',
        directEvidenceCount: 4,
        directness: '直接证据较强',
        reviewStatus: '待确认',
      );
      const governance = MentalHealthContentGovernanceEngine();
      final candidate = governance.createLocalDraft(
        plan: governance.buildGenerationQueue(const <CheckupIndicator>[
          indicator,
        ]).single,
        contentCode: 'A3',
        courseVersion: '2.5',
        now: DateTime.fromMillisecondsSinceEpoch(10),
      );
      final key = MentalHealthValidationEngine.participantKey(
        studySalt: 'private-study-salt',
        localAlias: 'local-person-01',
      );
      final raw = CheckupValidationEnvelope.create(
        courseVersion: '2.5',
        blueprintVersion: MentalHealthContentBlueprintFactory.version,
        candidates: <CheckupContentCandidate>[candidate],
        expertReviews: const <CheckupExpertReviewRecord>[],
        cognitiveInterviews: const <CheckupCognitiveInterviewRecord>[],
        pilotObservations: const <CheckupPilotObservation>[],
        seedReviews: const <CheckupSeedReviewRecord>[],
        now: DateTime.fromMillisecondsSinceEpoch(20),
      );

      expect(key, hasLength(64));
      expect(key, isNot(contains('local-person-01')));
      expect(
        CheckupValidationEnvelope.validateAndDecode(
          raw: raw,
          expectedCourseVersion: '2.5',
          expectedBlueprintVersion:
              MentalHealthContentBlueprintFactory.version,
        )['candidates'],
        hasLength(1),
      );
      expect(
        () => CheckupValidationEnvelope.validateAndDecode(
          raw: raw.replaceFirst(candidate.content, '被篡改'),
          expectedCourseVersion: '2.5',
          expectedBlueprintVersion:
              MentalHealthContentBlueprintFactory.version,
        ),
        throwsFormatException,
      );
    });
  });

  group('indicator candidate governance', () {
    const governance = MentalHealthIndicatorGovernanceEngine();

    test('AI cannot bypass independent review, pilot or human signing', () {
      var value = governance.createLocalDraft(
        lecture: 4,
        area: '情绪与认知',
        courseVersion: '2.5',
        evidenceLocationIds: const <String>[
          'L04-P001',
          'L04-P002',
          'L04-P003',
          'L04-P004',
        ],
        existingIndicatorIds: const <String>['I1'],
        now: DateTime.fromMillisecondsSinceEpoch(100),
      );
      value = value.copyWith(
        name: '情绪容纳后的有效行动',
        quality: const CheckupIndicatorCandidateQuality(
          courseEvidenceFit: 92,
          constructClarity: 90,
          nonDuplication: 88,
          measurability: 86,
          bidirectionalBalance: 85,
          actionability: 90,
          safety: 96,
        ),
        author: 'AI候选',
      );
      value = governance
          .transition(
            candidate: value,
            target: CheckupCandidateStage.candidate,
            actor: '内容编辑甲',
            note: '结构和质量门通过',
            existingIndicators: _catalog().indicators,
            now: DateTime.fromMillisecondsSinceEpoch(101),
          )
          .candidate
          .copyWith(
            evidenceReviewPassed: true,
            constructReviewPassed: true,
            expertReviewPassed: true,
          );

      expect(
        () => governance.transition(
          candidate: value,
          target: CheckupCandidateStage.cognitiveInterview,
          actor: 'AI审核',
          note: '自动审核',
        ),
        throwsStateError,
      );

      value = governance
          .transition(
            candidate: value,
            target: CheckupCandidateStage.cognitiveInterview,
            actor: '独立审核乙',
            note: '逐项复核证据、构念与课程边界',
            now: DateTime.fromMillisecondsSinceEpoch(102),
          )
          .candidate
          .copyWith(cognitiveInterviewPassed: true);
      value = governance
          .transition(
            candidate: value,
            target: CheckupCandidateStage.pilot,
            actor: '访谈员丙',
            note: '目标用户理解与预期一致',
            now: DateTime.fromMillisecondsSinceEpoch(103),
          )
          .candidate
          .copyWith(
            pilotPassed: true,
            pilotSampleSize: 30,
            pilotNotes: '缺失率、区分度、稳定性和安全反馈达到预设门槛。',
          );

      expect(
        () => governance.transition(
          candidate: value,
          target: CheckupCandidateStage.official,
          actor: '独立审核乙',
          note: '同一人签发',
          existingIndicators: _catalog().indicators,
        ),
        throwsStateError,
      );
      final official = governance.transition(
        candidate: value,
        target: CheckupCandidateStage.official,
        actor: '课程签发丁',
        note: '人工签发候选指标V1',
        existingIndicators: _catalog().indicators,
        now: DateTime.fromMillisecondsSinceEpoch(104),
      );

      expect(official.candidate.stage, CheckupCandidateStage.official);
      expect(official.candidate.reviewer, '独立审核乙');
      expect(official.candidate.signer, '课程签发丁');
      expect(
        official.candidate.toPublishedIndicator().id,
        official.candidate.proposedIndicatorId,
      );
    });

    test('published indicator enters catalog and retirement removes it', () {
      final seed = _catalog();
      final draft = governance.createLocalDraft(
        lecture: 4,
        area: '情绪与认知',
        courseVersion: '2.5',
        evidenceLocationIds: const <String>[
          'L04-P001',
          'L04-P002',
          'L04-P003',
          'L04-P004',
        ],
        now: DateTime.fromMillisecondsSinceEpoch(200),
      );
      final official = draft.copyWith(
        name: '情绪接纳后的功能恢复',
        quality: const CheckupIndicatorCandidateQuality(
          courseEvidenceFit: 95,
          constructClarity: 92,
          nonDuplication: 91,
          measurability: 88,
          bidirectionalBalance: 86,
          actionability: 90,
          safety: 98,
        ),
        stage: CheckupCandidateStage.official,
        evidenceReviewPassed: true,
        constructReviewPassed: true,
        expertReviewPassed: true,
        cognitiveInterviewPassed: true,
        pilotPassed: true,
        pilotSampleSize: 28,
        reviewer: '独立审核乙',
        signer: '课程签发丁',
      );

      final expanded = seed.withGovernedIndicators(<CheckupIndicatorCandidate>[
        official,
      ]);
      expect(expanded.indicatorById(official.proposedIndicatorId), isNotNull);

      final retired = official.copyWith(
        stage: CheckupCandidateStage.retired,
        retirementReason: '课程证据版本变化',
      );
      final withoutRetired = expanded.withGovernedIndicators(
        <CheckupIndicatorCandidate>[retired],
      );
      expect(
        withoutRetired.indicatorById(official.proposedIndicatorId),
        isNull,
      );
    });

    test('revision preserves formal indicator id and JSON audit fields', () {
      final official = governance
          .createLocalDraft(
            lecture: 4,
            area: '情绪与认知',
            courseVersion: '2.5',
            evidenceLocationIds: const <String>[
              'L04-P001',
              'L04-P002',
              'L04-P003',
              'L04-P004',
            ],
            now: DateTime.fromMillisecondsSinceEpoch(300),
          )
          .copyWith(
            stage: CheckupCandidateStage.official,
            version: 2,
            signer: '签发人',
          );
      final revision = governance.reviseOfficial(
        official: official,
        author: '修订者',
        now: DateTime.fromMillisecondsSinceEpoch(301),
      );
      final restored = CheckupIndicatorCandidate.fromJson(
        Map<String, dynamic>.from(revision.toJson()),
      );

      expect(revision.proposedIndicatorId, official.proposedIndicatorId);
      expect(revision.version, 3);
      expect(revision.parentCandidateId, official.candidateId);
      expect(restored.candidateId, revision.candidateId);
      expect(restored.evidenceLocationIds, revision.evidenceLocationIds);
    });
  });

  group('resumable generation and provider knowledge metadata', () {
    test('batch expands every unique item and B0-B4 slot', () {
      const plan = CheckupContentGenerationPlan(
        indicatorId: 'L04-C1',
        lecture: 4,
        indicatorName: '情绪接纳',
        indicatorType: '保护型',
        itemTypeCodes: <String>['A1', 'A2', 'A2'],
        behaviorLevels: <String>['B0', 'B1', 'B2', 'B3', 'B4'],
        evidenceIds: <String>['L04-P001'],
        guardrailIndicatorIds: <String>[],
        sourceLevel: 'C1',
        reviewStatus: '待审核',
      );
      final jobs = CheckupGenerationJob.expandPlans(
        batchId: 'batch-1',
        plans: const <CheckupContentGenerationPlan>[plan],
        useAi: true,
        now: DateTime.fromMillisecondsSinceEpoch(10),
      );

      expect(jobs, hasLength(7));
      expect(
        jobs.map((job) => job.contentCode).toSet(),
        containsAll(<String>['A1', 'A2', 'B0', 'B1', 'B2', 'B3', 'B4']),
      );
      expect(
        jobs.every((job) => job.status == CheckupGenerationJobStatus.queued),
        isTrue,
      );
      expect(
        CheckupGenerationJob.fromJson(
          Map<String, dynamic>.from(jobs.first.toJson()),
        ).id,
        jobs.first.id,
      );
    });

    test('provider file id is reusable only when ready and hash matches', () {
      const resource = CheckupProviderKnowledgeResource(
        id: 'provider-kb-openai-account-hash',
        provider: 'openai',
        providerLabel: 'OpenAI',
        accountFingerprint: 'account',
        providerFileId: 'file_123',
        providerResourceId: 'file_123',
        courseVersion: '2.5',
        sourceSha256: 'abcdef',
        fileName: 'course.jsonl',
        byteCount: 1024,
        status: CheckupKnowledgeResourceStatus.ready,
        enabled: true,
        uploadedAtMs: 1,
        lastVerifiedAtMs: 2,
      );
      final restored = CheckupProviderKnowledgeResource.fromJson(
        Map<String, dynamic>.from(resource.toJson()),
      );

      expect(restored.ready, isTrue);
      expect(restored.matchesCourse(version: '2.5', sha256: 'ABCDEF'), isTrue);
      expect(restored.matchesCourse(version: '2.6', sha256: 'abcdef'), isFalse);
      expect(restored.copyWith(enabled: false).ready, isFalse);
    });
  });
}

CheckupContentCandidate _officialContent({
  required String candidateId,
  required CheckupIndicator indicator,
  required String contentCode,
  CheckupContentKind kind = CheckupContentKind.assessmentItem,
  String? content,
  List<String> answerOptions = const <String>[],
  int? correctAnswerIndex,
}) =>
    CheckupContentCandidate(
      candidateId: candidateId,
      kind: kind,
      primaryIndicatorId: indicator.id,
      indicatorName: indicator.name,
      indicatorType: indicator.type,
      contentCode: contentCode,
      content: content ??
          (contentCode == 'A7'
              ? '下面哪项最符合“${indicator.name}”？'
              : '过去14天，“${indicator.name}”在现实生活中出现的程度是。'),
      scaleOrDuration: kind == CheckupContentKind.behaviorTask
          ? '每日1次，每次1分钟'
          : contentCode == 'A7'
              ? '情境判断单选'
              : '频率0—4',
      scoringDirection: contentCode == 'A7'
          ? '客观计分'
          : indicator.type.contains('风险')
              ? '越高风险越高'
              : '越高越健康',
      recallWindow: contentCode == 'A7' ? '此刻' : '过去14天',
      answerOptions: answerOptions,
      correctAnswerIndex: correctAnswerIndex,
      courseEvidenceIds: <String>[indicator.definitionLocation],
      sourceLevel: 'C1候选直接证据',
      constructRationale: '仅测量 ${indicator.id}：${indicator.name}。',
      guardrailIndicatorIds: const <String>[],
      safetyRule: kind == CheckupContentKind.behaviorTask
          ? '不得练习风险行为；若不适或现实功能变差立即停止。'
          : '若出现安全风险或明显不适，停止普通解释并进入安全复核。',
      smallerVersion: contentCode == 'B1' ? '缩小为10秒观察和一个安全动作。' : '',
      counterEvidencePrompt:
          contentCode == 'B2' || contentCode == 'B4' ? '记录反证和功能结果。' : '',
      quality: const CheckupCandidateQuality(
        indicatorConsistency: 95,
        courseFidelity: 95,
        nonDuplication: 90,
        measurability: 92,
        scaleWindowFit: 94,
        bidirectionalLogic: 90,
        safety: 98,
      ),
      stage: CheckupCandidateStage.official,
      evidenceReviewPassed: true,
      constructReviewPassed: true,
      cognitiveInterviewPassed: true,
      pilotPassed: true,
      pilotSampleSize: 24,
      pilotNotes: '认知访谈和小样本试测通过。',
      author: '作者甲',
      reviewer: '独立审核乙',
      signer: '课程签发丙',
      modelVersion: 'local-template',
      promptVersion: 'content-governance-v1',
      indicatorVersion: 'V2.3-345',
      courseVersion: '2.5',
      version: 1,
      createdAtMs: 100,
      updatedAtMs: 200,
    );

MentalHealthCheckupCatalog _catalogWithIndicator(CheckupIndicator indicator) {
  final base = _catalog();
  return MentalHealthCheckupCatalog(
    modes: base.modes,
    b20Questions: base.b20Questions,
    indicators: <CheckupIndicator>[...base.indicators, indicator],
    diagnosisPatterns: base.diagnosisPatterns,
    prescriptions: base.prescriptions,
    clinicalTerms: base.clinicalTerms,
    longitudinalCoverageRules: base.longitudinalCoverageRules,
    branchAlertRules: base.branchAlertRules,
    aiReportFields: base.aiReportFields,
    doseAndCourseRules: base.doseAndCourseRules,
    prescriptionAdjustmentRules: base.prescriptionAdjustmentRules,
    recoveryMaintenanceRules: base.recoveryMaintenanceRules,
    sourceBoundaryRules: base.sourceBoundaryRules,
    seedFieldMappings: base.seedFieldMappings,
    legacyContentCandidates: base.legacyContentCandidates,
    validation: base.validation,
  );
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
  double autonomy = 8,
  bool relapsePlanReady = true,
}) =>
    CheckupExecutionLog(
      createdAtMs: 1,
      completed: completed,
      effort: 3,
      benefit: 4,
      functionChange: 0,
      overuseRisk: overuse,
      autonomy: autonomy,
      relapsePlanReady: relapsePlanReady,
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
      autonomyScore: plan.averageAutonomy,
      relapsePlanReady: plan.hasRelapsePlan,
      retestScore: retest.overallScore,
      retestFunctionImpact: retest.functionImpact,
      safetyClear: retest.safetyClear,
      decision: '保持低剂量并再观察一周期',
      reason: '第一周期证据。',
    );
