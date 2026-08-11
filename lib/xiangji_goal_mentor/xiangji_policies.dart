import 'xiangji_models.dart';

/// Centralized state-machine rules shared by persistence and tests.
class XiangjiGoalTransitionPolicy {
  const XiangjiGoalTransitionPolicy._();

  static const Map<XiangjiGoalState, Set<XiangjiGoalState>> allowed =
      <XiangjiGoalState, Set<XiangjiGoalState>>{
    XiangjiGoalState.mist: <XiangjiGoalState>{XiangjiGoalState.spark},
    XiangjiGoalState.spark: <XiangjiGoalState>{
      XiangjiGoalState.anchored,
      XiangjiGoalState.mist,
      XiangjiGoalState.archived,
    },
    XiangjiGoalState.anchored: <XiangjiGoalState>{
      XiangjiGoalState.active,
      XiangjiGoalState.paused,
      XiangjiGoalState.reselecting,
    },
    XiangjiGoalState.active: <XiangjiGoalState>{
      XiangjiGoalState.feedback,
      XiangjiGoalState.paused,
      XiangjiGoalState.calibrating,
      XiangjiGoalState.completed,
    },
    XiangjiGoalState.feedback: <XiangjiGoalState>{
      XiangjiGoalState.active,
      XiangjiGoalState.calibrating,
      XiangjiGoalState.completed,
    },
    XiangjiGoalState.calibrating: <XiangjiGoalState>{
      XiangjiGoalState.active,
      XiangjiGoalState.paused,
      XiangjiGoalState.reselecting,
      XiangjiGoalState.completed,
    },
    XiangjiGoalState.paused: <XiangjiGoalState>{
      XiangjiGoalState.active,
      XiangjiGoalState.calibrating,
      XiangjiGoalState.reselecting,
      XiangjiGoalState.archived,
    },
    XiangjiGoalState.reselecting: <XiangjiGoalState>{
      XiangjiGoalState.spark,
      XiangjiGoalState.anchored,
      XiangjiGoalState.archived,
    },
    XiangjiGoalState.completed: <XiangjiGoalState>{
      XiangjiGoalState.archived,
      XiangjiGoalState.spark,
    },
    XiangjiGoalState.archived: <XiangjiGoalState>{},
  };

  static bool canTransition(XiangjiGoalState from, XiangjiGoalState to) {
    return allowed[from]?.contains(to) ?? false;
  }
}

/// Pure reminder rules. Keeping these out of the scheduler makes cadence,
/// quiet-hour handling and delivery keys deterministic and testable.
class XiangjiReminderPolicy {
  const XiangjiReminderPolicy._();

  static const int longSilenceDays = 7;
  static const int extendedSilenceDays = 21;

  static String outsideQuietHours(
    String selected, {
    required String quietStart,
    required String quietEnd,
  }) {
    final selectedMinute = _minutes(selected);
    final start = _minutes(quietStart);
    final end = _minutes(quietEnd);
    final inQuiet = start <= end
        ? selectedMinute >= start && selectedMinute < end
        : selectedMinute >= start || selectedMinute < end;
    return _formatMinutes(inQuiet ? end : selectedMinute);
  }

  /// Ordinary reminders are daily. After seven silent days they become
  /// reconnect reminders every three days, then weekly after day 21.
  static bool shouldSendForSilence(int silenceDays) {
    final safeDays = silenceDays < 0 ? 0 : silenceDays;
    if (safeDays >= extendedSilenceDays) {
      return (safeDays - extendedSilenceDays) % 7 == 0;
    }
    if (safeDays >= longSilenceDays) {
      return (safeDays - longSilenceDays) % 3 == 0;
    }
    return true;
  }

  static bool isLongSilence(int silenceDays) {
    return silenceDays >= longSilenceDays;
  }

  /// One key per goal and local calendar day enforces the product's default
  /// "at most once a day" rule even if more than one worker wakes up.
  static String deliveryKey({
    required int goalId,
    required DateTime localDate,
  }) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'goal:$goalId:${localDate.year}-${two(localDate.month)}-${two(localDate.day)}';
  }

  static int _minutes(String value) {
    final parts = value.trim().split(':');
    final hour = parts.isEmpty ? 9 : int.tryParse(parts.first) ?? 9;
    final minute = parts.length < 2 ? 0 : int.tryParse(parts[1]) ?? 0;
    return hour.clamp(0, 23).toInt() * 60 +
        minute.clamp(0, 59).toInt();
  }

  static String _formatMinutes(int value) {
    final hour = value ~/ 60;
    final minute = value % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
