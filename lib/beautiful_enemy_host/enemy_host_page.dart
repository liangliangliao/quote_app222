import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../beautiful_enemy/beautiful_enemy.dart';
import '../data/db.dart';
import 'enemy_ai_oracle.dart';
import 'enemy_ai_talker.dart';
import 'enemy_host_presence.dart';
import 'enemy_host_reminder.dart';
import 'enemy_sources.dart';
import 'enemy_voice_out.dart';

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
  final EnemyHostVoiceOut _voice = EnemyHostVoiceOut();

  @override
  void initState() {
    super.initState();
    // 页面打开期间由页面自己接话，全局插话让位。
    EnemyHostPresence.pageOpen = true;
  }

  @override
  void dispose() {
    EnemyHostPresence.pageOpen = false;
    _voice.stop();
    super.dispose();
  }

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
          talker: EnemyAiTalker(),
          voice: _voice,
          sources: defaultEnemySources(),
          reminder: const EnemyHostReminder(),
        );
      },
    );
  }
}
