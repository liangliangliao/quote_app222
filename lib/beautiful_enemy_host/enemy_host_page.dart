import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import 'enemy_ai_oracle.dart';
import 'enemy_host_reminder.dart';
import 'enemy_sources.dart';

/// 宿主侧的装配点：把已经打开的库、证据来源、判词生成器和提醒接上模块。
///
/// 宿主的 [AppDatabase.instance] 是异步的，路由表拿不到实例——所以这一层
/// 负责等库，再把 [EnemyEntry] 建出来。
class EnemyHostPage extends StatefulWidget {
  const EnemyHostPage({super.key});

  static const Key loadingKey = ValueKey<String>('beautiful_enemy_host_loading');

  @override
  State<EnemyHostPage> createState() => _EnemyHostPageState();
}

class _EnemyHostPageState extends State<EnemyHostPage> {
  late final Future<Database> _db = AppDatabase.instance();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Database>(
      future: _db,
      builder: (BuildContext context, AsyncSnapshot<Database> snapshot) {
        final Database? db = snapshot.data;
        if (db == null) {
          return const Scaffold(
            key: EnemyHostPage.loadingKey,
            backgroundColor: Color(0xFF14100F),
            body: SizedBox.shrink(),
          );
        }
        return EnemyEntry.build(
          db: db,
          // AI 只是增强：没配置或调用失败会自己落回本地事实播报。
          oracle: EnemyAiOracle(),
          sources: defaultEnemySources(),
          reminder: const EnemyHostReminder(),
        );
      },
    );
  }
}
