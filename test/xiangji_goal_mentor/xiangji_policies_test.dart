import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_models.dart';
import 'package:quote_app/xiangji_goal_mentor/xiangji_policies.dart';

void main() {
  group('goal transition policy', () {
    test('allows the documented forward and calibration transitions', () {
      expect(
        XiangjiGoalTransitionPolicy.canTransition(
          XiangjiGoalState.mist,
          XiangjiGoalState.spark,
        ),
        isTrue,
      );
      expect(
        XiangjiGoalTransitionPolicy.canTransition(
          XiangjiGoalState.active,
          XiangjiGoalState.calibrating,
        ),
        isTrue,
      );
      expect(
        XiangjiGoalTransitionPolicy.canTransition(
          XiangjiGoalState.calibrating,
          XiangjiGoalState.reselecting,
        ),
        isTrue,
      );
    });

    test('rejects shortcuts and any transition out of archived', () {
      expect(
        XiangjiGoalTransitionPolicy.canTransition(
          XiangjiGoalState.mist,
          XiangjiGoalState.completed,
        ),
        isFalse,
      );
      for (final target in XiangjiGoalState.values) {
        expect(
          XiangjiGoalTransitionPolicy.canTransition(
            XiangjiGoalState.archived,
            target,
          ),
          isFalse,
        );
      }
    });
  });

  group('reminder policy', () {
    test('moves an overnight quiet-hour selection to quiet end', () {
      expect(
        XiangjiReminderPolicy.outsideQuietHours(
          '23:30',
          quietStart: '22:00',
          quietEnd: '08:00',
        ),
        '08:00',
      );
      expect(
        XiangjiReminderPolicy.outsideQuietHours(
          '09:05',
          quietStart: '22:00',
          quietEnd: '08:00',
        ),
        '09:05',
      );
    });

    test('normalizes malformed or out-of-range times', () {
      expect(
        XiangjiReminderPolicy.outsideQuietHours(
          '99:99',
          quietStart: '22:00',
          quietEnd: '08:00',
        ),
        '08:00',
      );
      expect(
        XiangjiReminderPolicy.outsideQuietHours(
          'bad',
          quietStart: '22:00',
          quietEnd: '08:00',
        ),
        '09:00',
      );
    });

    test('degrades long-silence cadence without exposing failure days', () {
      expect(XiangjiReminderPolicy.shouldSendForSilence(0), isTrue);
      expect(XiangjiReminderPolicy.shouldSendForSilence(6), isTrue);
      expect(XiangjiReminderPolicy.shouldSendForSilence(7), isTrue);
      expect(XiangjiReminderPolicy.shouldSendForSilence(8), isFalse);
      expect(XiangjiReminderPolicy.shouldSendForSilence(10), isTrue);
      expect(XiangjiReminderPolicy.shouldSendForSilence(21), isTrue);
      expect(XiangjiReminderPolicy.shouldSendForSilence(22), isFalse);
      expect(XiangjiReminderPolicy.shouldSendForSilence(28), isTrue);
    });

    test('uses one deterministic key per local calendar day', () {
      expect(
        XiangjiReminderPolicy.deliveryKey(
          goalId: 42,
          localDate: DateTime(2026, 8, 2, 23, 59),
        ),
        'goal:42:2026-08-02',
      );
    });
  });

  test('check-in and evidence contracts expose every specified value', () {
    expect(
      XiangjiCheckinResult.values.map((item) => item.value),
      unorderedEquals(<String>[
        'completed',
        'partially_completed',
        'not_started',
        'blocked',
        'no_longer_relevant',
      ]),
    );
    expect(
      XiangjiEvidenceType.values.map((item) => item.value),
      unorderedEquals(<String>[
        'action',
        'learning',
        'strategy_change',
        'boundary',
        'help_seeking',
        'rest_and_recovery',
        'goal_exit',
        'contribution',
      ]),
    );
    expect(
      XiangjiCheckinResult.noLongerRelevant.defaultEvidenceType,
      XiangjiEvidenceType.goalExit,
    );
  });
}
