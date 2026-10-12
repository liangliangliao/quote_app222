import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../zhaojian/zhaojian.dart';
import 'zhaojian_ai_oracle.dart';

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
          // AI 只是增强：没配置或调用失败会自己落回内置动机库与规则推荐。
          oracle: ZhaojianAiOracle(),
        );
      },
    );
  }
}
