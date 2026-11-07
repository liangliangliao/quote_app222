import 'package:flutter/widgets.dart';

import 'domain/enemy_engine.dart';

/// 一条字据的最小信息，交给宿主用。
class EnemyCommitmentInfo {
  const EnemyCommitmentInfo({
    required this.id,
    required this.text,
    required this.createdMs,
    this.dueMs,
    this.stake = '',
  });

  final int id;
  final String text;
  final int createdMs;
  final int? dueMs;
  final String stake;
}

/// 宿主可以接管“失败之后做什么”（例如 PRP 插件：缓一缓 → 对账 → 盖印）。
/// 模块自己不依赖任何宿主代码；宿主没接就是 [NoopEnemyFailureHook]，模块走原有的归因弹层。
abstract class EnemyFailureHook {
  const EnemyFailureHook();

  /// 用户标记“没做到”之后。返回 true 表示宿主已经接管，模块不再弹原有的归因弹层。
  Future<bool> onMissed(
    BuildContext context,
    EnemyEngine engine,
    EnemyCommitmentInfo info,
  );

  /// 新字据创建成功之后（宿主可以据此把它和相关教训挂上，之后验证）。
  Future<void> onCommitmentCreated(EnemyCommitmentInfo info);

  /// 字据输入框上方的宿主插槽（例如“类似的事你上次盖印过……”）。不接返回空组件。
  Widget commitmentHint(BuildContext context, TextEditingController text);

  /// 教训页顶部的宿主插槽（例如教训手册）。不接返回空组件。
  Widget lessonsHeader(BuildContext context);
}

class NoopEnemyFailureHook extends EnemyFailureHook {
  const NoopEnemyFailureHook();

  @override
  Future<bool> onMissed(
    BuildContext context,
    EnemyEngine engine,
    EnemyCommitmentInfo info,
  ) async => false;

  @override
  Future<void> onCommitmentCreated(EnemyCommitmentInfo info) async {}

  @override
  Widget commitmentHint(BuildContext context, TextEditingController text) =>
      const SizedBox.shrink();

  @override
  Widget lessonsHeader(BuildContext context) => const SizedBox.shrink();
}

/// 宿主在启动时把自己的实现挂到这里。
class EnemyHostHooks {
  const EnemyHostHooks._();

  static EnemyFailureHook failure = const NoopEnemyFailureHook();
}
