import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import '../prp_plugin/prp_plugin.dart';
import 'enemy_failure_hook_impl.dart';
import 'prp_host_impl.dart';

/// 启动时调用一次：把 PRP 插件接到 App 上。
/// 不访问数据库、不起任何后台任务；真正的读写发生在用户使用到的时候。
/// 总开关默认关闭，所以这一步之后 App 的行为与此前完全一致。
void installPrpPlugin() {
  try {
    final PrpCore core = PrpCore(
      store: SqflitePrpStore(AppDatabase.instance),
      host: PrpHostImpl(),
      settings: PrpSettings(KeyValueDaoPrpKv()),
    );
    PrpPlugin.instance = RealPrpPlugin(core);
    EnemyHostHooks.failure = const PrpEnemyFailureHook();
  } catch (_) {
    // 插件装不上就保持 Noop，不影响 App 启动。
  }
}
