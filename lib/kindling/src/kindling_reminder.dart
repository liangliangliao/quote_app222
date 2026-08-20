/// 「说不准」的复问提醒。
///
/// 方案 §5.3 把本地通知列为可选、默认关。模块不引入通知依赖，只把时机交出去：
/// 宿主愿意接就接，不接就是默认的 [NoopKindlingReminder]，此时复问仍然会在
/// 下次进入模块时发生，只是不会有系统通知。
abstract class KindlingReminder {
  /// 判别式答了「说不准」。[askAgainAt] 是允许再问的时刻。
  Future<void> onUnsureRecorded({
    required int itemId,
    required String title,
    required DateTime askAgainAt,
  });

  /// 这条火种不需要再复问了（重新作答、被放掉或已复问）。
  Future<void> onReaskResolved({required int itemId});
}

/// 默认实现：什么都不做，也就是「默认关」。
class NoopKindlingReminder implements KindlingReminder {
  const NoopKindlingReminder();

  @override
  Future<void> onUnsureRecorded({
    required int itemId,
    required String title,
    required DateTime askAgainAt,
  }) async {}

  @override
  Future<void> onReaskResolved({required int itemId}) async {}
}
