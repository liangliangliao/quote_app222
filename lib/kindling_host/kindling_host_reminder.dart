import 'package:workmanager/workmanager.dart';

import '../data/kv_dao.dart';
import '../kindling/kindling.dart';
import '../services/notification_service.dart';

/// 「说不准」7 天后的本地通知（方案 §5.3，可选，默认关）。
///
/// 模块本身不碰通知，只把时机交出来；这里用宿主已有的 Workmanager 一次性任务
/// 排期，到点由 [handleWork] 弹一条通知。关掉开关时只是不排期——应用内的复问
/// 照旧发生，不受影响。
class KindlingHostReminder implements KindlingReminder {
  const KindlingHostReminder();

  /// wm_dispatcher 里的分发标识。
  static const String workJob = 'kindling_reask';

  /// 开关键。缺省即关。
  static const String enabledKey = 'kindling.reask_notify_enabled';

  static const String notificationPayload = 'kindling';

  /// 通知 id 的基数，避开宿主其它模块用的区间。
  static const int _notificationIdBase = 91000;

  static String _taskName(int itemId) => 'kindling_reask_$itemId';

  static Future<bool> isEnabled() async {
    final String? raw = await KeyValueDao().getString(enabledKey);
    return raw == '1';
  }

  static Future<void> setEnabled(bool enabled) async {
    await KeyValueDao().setString(enabledKey, enabled ? '1' : '0');
  }

  @override
  Future<void> onUnsureRecorded({
    required int itemId,
    required String title,
    required DateTime askAgainAt,
  }) async {
    await _cancel(itemId);
    if (!await isEnabled()) return;

    Duration delay = askAgainAt.difference(DateTime.now());
    if (delay < const Duration(minutes: 1)) {
      delay = const Duration(minutes: 1);
    }
    try {
      await Workmanager().registerOneOffTask(
        _taskName(itemId),
        'wm_task',
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        inputData: <String, dynamic>{
          'job': workJob,
          'item_id': itemId,
          'title': title,
        },
      );
    } catch (_) {
      // 排不上就算了：应用内复问仍然会发生，不该因为通知失败而打断判别式。
    }
  }

  @override
  Future<void> onReaskResolved({required int itemId}) => _cancel(itemId);

  Future<void> _cancel(int itemId) async {
    try {
      await Workmanager().cancelByUniqueName(_taskName(itemId));
    } catch (_) {
      // 没排过就没什么好取消的。
    }
  }

  /// 到点执行：弹一条通知，内容就是判别式那一问。
  ///
  /// 这里不再回查数据库——重新作答、被放掉、或已在应用内复问过，都会在当时
  /// 调用 [onReaskResolved] 把任务撤掉，所以能走到这里的就是还没了结的。
  static Future<void> handleWork(Map<String, dynamic>? inputData) async {
    final Object? rawId = inputData?['item_id'];
    final int itemId =
        rawId is int ? rawId : int.tryParse('${rawId ?? ''}') ?? 0;
    final String title = (inputData?['title'] ?? '').toString().trim();
    if (itemId <= 0) return;
    if (!await isEnabled()) return;

    await NotificationService.show(
      id: _notificationIdBase + (itemId % 1000),
      title: title.isEmpty ? KindlingCopy.title : title,
      body: KindlingCopy.verdictQuestion,
      payload: notificationPayload,
    );
  }
}

/// 通知里要用到的两句文案。
///
/// 模块把文案锁在 library private 的 copy.dart 里，宿主拿不到；这两句必须与
/// 模块内一致，由 test/kindling/kindling_host_test.dart 逐字比对守住。
class KindlingCopy {
  const KindlingCopy._();

  static const String title = '火种';
  static const String verdictQuestion = '如果没人知道你做了这件事，你还做吗？';
}
