import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/enemy_dao.dart';
import 'domain/enemy_engine.dart';
import 'domain/evidence_source.dart';
import 'enemy_oracle.dart';
import 'enemy_reminder.dart';
import 'ui/enemy_home_page.dart';

/// 美丽的敌人模块的入口。
///
/// 模块不自己开库：宿主把已经打开的 [Database]、判词生成器和证据来源交进来。
/// 进场时会幂等地建表，所以宿主没有必要在开库路径上替它建表。
class EnemyEntry {
  const EnemyEntry._();

  static const String route = '/beautiful_enemy';

  /// 只造引擎、不造界面。后台任务（每日通知）和测试用它。
  static Future<EnemyEngine> buildEngine({
    required Database db,
    EnemyOracle oracle = const LocalFactOracle(),
    List<EvidenceSource> sources = const <EvidenceSource>[],
    DateTime Function()? clock,
  }) async {
    final EnemyDao dao = EnemyDao(db);
    await dao.ensureSchema();
    return EnemyEngine(dao: dao, oracle: oracle, sources: sources, clock: clock);
  }

  static Widget build({
    required Database db,
    EnemyOracle oracle = const LocalFactOracle(),
    List<EvidenceSource> sources = const <EvidenceSource>[],
    EnemyReminder reminder = const NoopEnemyReminder(),
  }) {
    return _EnemyLoader(db: db, oracle: oracle, sources: sources, reminder: reminder);
  }
}

class _EnemyLoader extends StatefulWidget {
  const _EnemyLoader({
    required this.db,
    required this.oracle,
    required this.sources,
    required this.reminder,
  });

  final Database db;
  final EnemyOracle oracle;
  final List<EvidenceSource> sources;
  final EnemyReminder reminder;

  @override
  State<_EnemyLoader> createState() => _EnemyLoaderState();
}

class _EnemyLoaderState extends State<_EnemyLoader> {
  late final Future<EnemyEngine> _engine = EnemyEntry.buildEngine(
    db: widget.db,
    oracle: widget.oracle,
    sources: widget.sources,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EnemyEngine>(
      future: _engine,
      builder: (BuildContext context, AsyncSnapshot<EnemyEngine> snapshot) {
        final EnemyEngine? engine = snapshot.data;
        if (engine == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF14100F),
            body: SizedBox.shrink(),
          );
        }
        return EnemyHomePage(engine: engine, reminder: widget.reminder);
      },
    );
  }
}
