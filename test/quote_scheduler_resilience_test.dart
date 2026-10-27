import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/widgets/task_schedule_status.dart';

void main() {
  test(
    'task status distinguishes last execution, next execution and countdown',
    () {
      final next = DateTime(2026, 10, 27, 10, 57);

      expect(formatTaskScheduleTime(null), '尚无记录');
      expect(formatTaskScheduleTime(next), '2026-10-27 10:57:00');
      expect(
        taskScheduleCountdown(next, DateTime(2026, 10, 27, 10, 42, 30)),
        '还有 14分30秒',
      );
      expect(
        taskScheduleCountdown(next, DateTime(2026, 10, 27, 10, 58)),
        contains('等待系统触发'),
      );
    },
  );

  test('task schedule presents localized frequency rules', () {
    expect(
      taskScheduleFrequencyLabel(<String, dynamic>{
        'freq_type': 'interval',
        'freq_custom': '{"interval_minutes":15}',
      }),
      '每 15 分钟',
    );
    expect(
      taskScheduleFrequencyLabel(<String, dynamic>{
        'freq_type': 'weekly',
        'freq_weekday': 3,
        'start_time': '2026-10-28 09:05:00',
      }),
      '每周三 09:05',
    );
  });

  test('Android boot recovery is routed into the Dart task scheduler', () {
    final boot = File(
      'android/app/src/main/kotlin/com/example/quote_app/BootReceiver.kt',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(boot, contains('OneTimeWorkRequestBuilder<BackgroundWorker>()'));
    expect(boot, contains('BackgroundWorker.DART_TASK_KEY'));
    expect(boot, contains('.putString("payload_job", "wm_boot")'));
    expect(boot, contains('"quote_task_boot_restore"'));
    expect(
      main.indexOf('Workmanager().initialize(workmanagerCallbackDispatcher'),
      lessThan(main.indexOf('await SchedulerService.scheduleNextForAll()')),
    );
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    expect(manifest, contains('android.intent.action.USER_UNLOCKED'));
  });

  test('successful Dart and native runs persist a last-run timestamp', () {
    final scheduler = File(
      'lib/services/scheduler_service.dart',
    ).readAsStringSync();
    final schema = File('lib/data/db.dart').readAsStringSync();
    final nativeRepository = File(
      'android/app/src/main/java/com/example/quote_app/data/DbRepository.java',
    ).readAsStringSync();

    expect(scheduler, contains('TaskDao().markLastRun(uid)'));
    expect(schema, contains('last_run_at TEXT'));
    expect(nativeRepository, contains('values.put("last_run_at"'));
  });
}
