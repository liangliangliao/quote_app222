import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/health_diet/services/health_diet_daily_scheduler_service.dart';

class _Scheduler extends HealthDietDailySchedulerService {
  bool forced = true;
  bool fail = false;
  int rescheduled = 0;
  @override
  Future<HealthDietScheduleRunResult> runSlot(String slotId, {String userId = 'default_user', bool force = false, String from = 'manual'}) async {
    forced = force;
    if (fail) throw StateError('AI unavailable');
    return HealthDietScheduleRunResult(slot: HealthDietDailySchedulerService.defaultSlots.first, ran: false, message: 'disabled');
  }
  @override
  Future<int> syncSchedules({String userId = 'default_user'}) async { rescheduled++; return 0; }
}

void main() {
  test('background run respects settings rather than forcing disabled work', () async {
    final scheduler = _Scheduler();
    await scheduler.runScheduledSlot('morning_plan');
    expect(scheduler.forced, isFalse);
    expect(scheduler.rescheduled, 1);
  });
  test('AI failure cannot break subsequent daily scheduling', () async {
    final scheduler = _Scheduler()..fail = true;
    await expectLater(scheduler.runScheduledSlot('morning_plan'), throwsStateError);
    expect(scheduler.rescheduled, 1);
  });
}
