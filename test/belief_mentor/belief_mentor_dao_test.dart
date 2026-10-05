import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/belief_lab/belief_mentor_dao.dart';
import 'package:quote_app/belief_lab/belief_mentor_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database database;
  late BeliefMentorDao dao;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    dao = BeliefMentorDao(database: database);
    await dao.ensureSchema(database);
  });

  tearDown(() => database.close());

  test(
    'seeds eight boundary-labeled stories and persists the evidence loop',
    () async {
      expect(await dao.stories(), hasLength(8));

      final now = DateTime.now();
      final belief = BeliefMentorBelief(
        id: 'belief-1',
        statement: '如果不能一次做好，就不该开始',
        type: BeliefMentorBeliefType.action,
        strength: 75,
        initialStrength: 75,
        trigger: '需要公开提交',
        alternativeStatement: '最小版本可以先提供信息',
        state: BeliefMentorBeliefState.alternativeFormed,
        userConfirmed: true,
        createdAtMs: now.millisecondsSinceEpoch,
        updatedAtMs: now.millisecondsSinceEpoch,
      );
      await dao.saveBelief(belief);
      final experiment = await dao.createExperiment(
        beliefId: belief.id,
        draft: const BeliefMentorExperimentDraft(
          action: '提交一个最小草稿',
          minimumVersion: '先写标题和三条要点',
          fallbackAction: '创建空白文档并约定明天时间',
          difficulty: 4,
          completionProbability: 80,
          rationale: '取得一条现实信息',
        ),
        scheduledAt: now.add(const Duration(hours: 2)),
      );
      await dao.startExperiment(experiment.id, source: 'self');
      await dao.completeExperiment(experiment.id);
      await dao.saveEvidence(
        BeliefMentorEvidence(
          id: 'evidence-1',
          beliefId: belief.id,
          experimentId: experiment.id,
          prediction: '草稿会被否定',
          action: '提交了三条要点',
          outcome: '对方给了一个具体修改建议',
          emotionBefore: 8,
          emotionAfter: 4,
          learning: '先提交最小版本能换来信息',
          statement: '在这次低风险提交里，不完美没有阻止我获得反馈',
          strength: BeliefMentorEvidenceStrength.strong,
          predictedFailureProbability: 80,
          predictionOccurred: false,
          createdAtMs: now.add(const Duration(hours: 3)).millisecondsSinceEpoch,
        ),
      );

      expect(
        (await dao.experiment(experiment.id))!.state,
        BeliefMentorExperimentState.evidenceCreated,
      );
      expect(await dao.evidence(beliefId: belief.id), hasLength(1));
      expect(
        (await dao.evidence(beliefId: belief.id))
            .single
            .predictedFailureProbability,
        80,
      );
      expect(
        (await dao.belief(belief.id))!.state,
        BeliefMentorBeliefState.evidenceAccumulating,
      );

      final exported =
          jsonDecode(await dao.exportData()) as Map<String, dynamic>;
      expect(exported['schema'], 'belief-mentor-export-v1');
      expect(exported['belief_mentor_evidence'], hasLength(1));
    },
  );

  test('one failed experiment owns only one open recovery protocol', () async {
    final first = await dao.createFailure(
      beliefId: 'belief-1',
      experimentId: 'experiment-1',
      facts: '没有在计划时间开始',
      interpretation: '我永远做不到',
      emotion: '挫败',
      nextStep: '打开文档两分钟',
    );
    final duplicate = await dao.createFailure(
      beliefId: 'belief-1',
      experimentId: 'experiment-1',
      facts: '重复提交',
      interpretation: '',
      emotion: '',
      nextStep: '',
    );

    expect(duplicate.id, first.id);
    expect(await dao.failures(openOnly: true), hasLength(1));
    await expectLater(
      dao.createFailure(
        beliefId: 'belief-1',
        experimentId: 'experiment-1',
        facts: '我不想活了',
        interpretation: '',
        emotion: '',
        nextStep: '',
      ),
      throwsStateError,
      reason: '重复写入也不能绕过高风险语言的硬拦截',
    );
  });

  test('P1 calendar and Past Me records are encrypted and deletable', () async {
    final now = DateTime.now();
    final event = BeliefMentorCalendarEvent(
      id: 'calendar-1',
      beliefId: 'belief-1',
      title: '重要汇报',
      context: '向团队解释方案并接受提问',
      eventAtMs: now.add(const Duration(days: 8)).millisecondsSinceEpoch,
      timezone: now.timeZoneName,
      state: BeliefMentorCalendarEventState.scheduled,
      createdAtMs: now.millisecondsSinceEpoch,
      updatedAtMs: now.millisecondsSinceEpoch,
    );
    final message = BeliefMentorPastMeMessage(
      id: 'past-me-1',
      beliefId: 'belief-1',
      text: '你已经用最小行动得到过真实反馈。',
      audioPath: '/private/message.m4a',
      deliverAtMs: now.add(const Duration(days: 1)).millisecondsSinceEpoch,
      state: BeliefMentorPastMeMessageState.scheduled,
      isPrivate: true,
      createdAtMs: now.millisecondsSinceEpoch,
      updatedAtMs: now.millisecondsSinceEpoch,
    );

    await dao.saveCalendarEvent(event);
    await dao.savePastMeMessage(message);

    final rawEvent = (await database.query('belief_mentor_calendar_events'))
        .single;
    final rawMessage = (await database.query('belief_mentor_past_me_messages'))
        .single;
    expect(rawEvent['title'], startsWith('development:'));
    expect(rawEvent['context_text'], startsWith('development:'));
    expect(rawMessage['message_text'], startsWith('development:'));
    expect(rawMessage['audio_path'], startsWith('development:'));
    expect((await dao.calendarEvents()).single.title, event.title);
    expect((await dao.pastMeMessages()).single.text, message.text);

    await dao.deleteCalendarEvent(event.id);
    await dao.deletePastMeMessage(message.id);

    expect(await dao.calendarEvents(includeClosed: true), isEmpty);
    expect(await dao.pastMeMessages(), isEmpty);
    final audit = await database.query('belief_mentor_privacy_audit');
    expect(
      audit.map((row) => row['event_name']),
      containsAll(<String>[
        'belief_calendar_event_deleted',
        'past_me_message_deleted',
      ]),
    );
  });

  test(
    'delete removes all user data while preserving reviewed story seeds',
    () async {
      final profile = await dao.profile();
      await dao.saveProfile(profile.copyWith(onboardingCompleted: true));
      await dao.track('onboarding_completed');

      await dao.deleteAllUserData();

      expect(await database.query('belief_mentor_profile'), isEmpty);
      expect(await database.query('belief_mentor_events'), isEmpty);
      expect(await dao.stories(), hasLength(8));
    },
  );
}
