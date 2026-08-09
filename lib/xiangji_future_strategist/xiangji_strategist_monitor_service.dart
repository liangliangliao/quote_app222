import 'package:workmanager/workmanager.dart';

import '../data/kv_dao.dart';
import '../services/notification_service.dart';
import 'xiangji_database.dart';
import 'xiangji_models.dart';
import 'xiangji_repository.dart';

/// Rev.4 background strategist watches only for changes that can alter the
/// current route. The toggle is authoritative: disabling it cancels the
/// periodic work instead of merely hiding notifications.
class XiangjiStrategistMonitorService {
  const XiangjiStrategistMonitorService._();

  static const String job = 'xiangji_strategist_monitor';
  static const String uniqueName = 'xiangji_strategist_monitor_periodic_v1';
  static const String taskName = 'xiangji_strategist_monitor_task';

  static Future<void> syncSchedule() async {
    final enabled =
        (await KeyValueDao().getString(XiangjiRepository.monitorEnabledKey)) !=
            '0';
    if (!enabled) {
      await Workmanager().cancelByUniqueName(uniqueName);
      return;
    }
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(hours: 6),
      initialDelay: const Duration(minutes: 30),
      inputData: const <String, dynamic>{'job': job},
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
  }

  static Future<bool> runScheduled() async {
    final enabled =
        (await KeyValueDao().getString(XiangjiRepository.monitorEnabledKey)) !=
            '0';
    if (!enabled) return true;
    final dao = XiangjiDao();
    await dao.ensureSchema();
    const alertType = 'rev4_background_watch';
    final before = await dao.latestOpenAlertForType(alertType);
    final result = await XiangjiRepository(dao: dao).refreshAutomaticWatch();
    final after = await dao.latestOpenAlertForType(alertType);
    final isNew = after != null &&
        (after['id'] ?? '').toString() != (before?['id'] ?? '').toString();
    if (!isNew ||
        !<XiangjiAlertState>{
          XiangjiAlertState.orange,
          XiangjiAlertState.red,
          XiangjiAlertState.blue,
        }.contains(result.state)) {
      return true;
    }
    final problemId = (after['problem_id'] ?? '').toString();
    await NotificationService.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: switch (result.state) {
        XiangjiAlertState.red => '军师发现一项不可继续忽略的风险',
        XiangjiAlertState.orange => '军师建议暂停加码并重新核对',
        XiangjiAlertState.blue => '军师发现可能值得把握的新条件',
        _ => '军师发现会改变路线的新现实',
      },
      body: result.reason,
      payload: 'xiangji_future_strategist:$problemId',
    );
    return true;
  }
}
