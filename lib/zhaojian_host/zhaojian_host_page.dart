import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../evidence_growth/evidence_growth_dao.dart';
import '../evidence_growth/evidence_growth_discovery.dart' show GrowthJevAccess;
import '../zhaojian/zhaojian.dart';
import 'zhaojian_ai_oracle.dart';
import 'zhaojian_host_oracle.dart';
import 'zhaojian_jev_oracle.dart';

/// 宿主侧的装配点：把已经打开的库和 AI 引擎接上模块。
///
/// 模块不自己开库，而宿主的 [AppDatabase.instance] 是异步的，路由表拿不到
/// 实例——所以这一层负责等库，再把 [ZhaojianEntry] 建出来。
class ZhaojianHostPage extends StatefulWidget {
  const ZhaojianHostPage({super.key});

  static const Key loadingKey = ValueKey<String>('zhaojian_host_loading');

  @override
  State<ZhaojianHostPage> createState() => _ZhaojianHostPageState();
}

class _ZhaojianHostPageState extends State<ZhaojianHostPage> {
  late final Future<Database> _db = AppDatabase.instance();

  /// 只用来读「证据成长」里已配置的 JEV 密钥，不写任何数据。
  late final EvidenceGrowthDao _jevDao =
      EvidenceGrowthDao(database: AppDatabase.instance);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _db,
      builder: (BuildContext context, AsyncSnapshot<Database> snapshot) {
        final Database? db = snapshot.data;
        if (db == null) {
          return const Scaffold(
            key: ZhaojianHostPage.loadingKey,
            backgroundColor: Colors.white,
            body: SizedBox.shrink(),
          );
        }
        return ZhaojianEntry.build(
          db: db,
          // AI 与 JEV 都只是增强：没配置或调用失败会自己落回内置动机库与规则推荐。
          oracle: ZhaojianHostOracle(
            text: ZhaojianAiOracle(),
            scorer: ZhaojianJevOracle(
              readKey: () => GrowthJevAccess.key(_jevDao),
            ),
          ),
        );
      },
    );
  }
}
