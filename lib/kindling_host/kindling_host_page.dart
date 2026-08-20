import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';
import '../kindling/kindling.dart';
import 'kindling_ai_oracle.dart';
import 'kindling_host_reminder.dart';

/// 宿主侧的装配点：把已经打开的库、追问器和提醒接上模块。
///
/// 模块不自己开库，而宿主的 [AppDatabase.instance] 是异步的，路由表拿不到
/// 实例——所以这一层负责等库，再把 [KindlingEntry] 建出来。
class KindlingHostPage extends StatefulWidget {
  const KindlingHostPage({super.key});

  static const Key loadingKey = ValueKey<String>('kindling_host_loading');

  @override
  State<KindlingHostPage> createState() => _KindlingHostPageState();
}

class _KindlingHostPageState extends State<KindlingHostPage> {
  late final Future<Database> _db = AppDatabase.instance();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _db,
      builder: (BuildContext context, AsyncSnapshot<Database> snapshot) {
        final Database? db = snapshot.data;
        if (db == null) {
          // 等库期间保持白屏，不放加载动画——这一屏不该有任何进度感。
          return const Scaffold(
            key: KindlingHostPage.loadingKey,
            backgroundColor: Colors.white,
            body: SizedBox.shrink(),
          );
        }
        return KindlingEntry.build(
          db: db,
          // AI 只是增强：没配置或调用失败会自己落回本地实现。
          oracle: KindlingAiOracle(),
          reminder: const KindlingHostReminder(),
        );
      },
    );
  }
}
