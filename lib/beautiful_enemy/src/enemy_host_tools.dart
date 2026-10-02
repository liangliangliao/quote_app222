/// 宿主能做、模块自己做不了的事：通知、后台任务。自检页上的按钮用它。
///
/// 模块不引入通知和后台任务的依赖；不接就是 [NoopEnemyHostTools]，按钮会说明「宿主没接」。
abstract class EnemyHostTools {
  /// 立刻发一条测试通知。成功返回空串，失败返回原因。
  Future<String> testNotification(String text);

  /// （重新）登记后台巡查任务。成功返回空串，失败返回原因。
  Future<String> scheduleBackgroundPatrol();

  /// 10 秒后在**真正的后台**跑一次巡查，用来验证后台通路。成功登记返回空串，失败返回原因。
  Future<String> runBackgroundPatrolOnce();
}

class NoopEnemyHostTools implements EnemyHostTools {
  const NoopEnemyHostTools();

  static const String notWired = '宿主没有接这个能力。';

  @override
  Future<String> testNotification(String text) async => notWired;

  @override
  Future<String> scheduleBackgroundPatrol() async => notWired;

  @override
  Future<String> runBackgroundPatrolOnce() async => notWired;
}
