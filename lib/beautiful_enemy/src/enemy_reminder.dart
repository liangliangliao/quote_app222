/// 每日报到通知的挂载点。
///
/// 模块不引入通知依赖，只把开关和时间交出去；宿主愿意接就接，不接就是
/// 默认的 [NoopEnemyReminder]，此时只是没有系统通知，应用内一切照常。
abstract class EnemyReminder {
  /// 用户改了「每日报到通知」的开关或时间。
  Future<void> onDailyNotifyChanged({required bool enabled, required int hour});
}

class NoopEnemyReminder implements EnemyReminder {
  const NoopEnemyReminder();

  @override
  Future<void> onDailyNotifyChanged({required bool enabled, required int hour}) async {}
}
