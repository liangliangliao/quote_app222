import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'data/enemy_dao.dart';
import 'domain/enemy_engine.dart';
import 'domain/enemy_presence.dart';
import 'domain/evidence_source.dart';
import 'enemy_oracle.dart';
import 'enemy_reminder.dart';
import 'enemy_talker.dart';
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

  /// 引擎 + 在场（对话、实时插话）。宿主的全局插话和测试都用它。
  static Future<EnemyPresence> buildPresence({
    required Database db,
    EnemyOracle oracle = const LocalFactOracle(),
    EnemyTalker? talker,
    List<EvidenceSource> sources = const <EvidenceSource>[],
    DateTime Function()? clock,
  }) async {
    final EnemyEngine engine = await buildEngine(
      db: db,
      oracle: oracle,
      sources: sources,
      clock: clock,
    );
    return EnemyPresence(engine: engine, talker: talker);
  }

  static Widget build({
    required Database db,
    EnemyOracle oracle = const LocalFactOracle(),
    EnemyTalker? talker,
    EnemyVoiceOut voice = const NoopEnemyVoiceOut(),
    List<EvidenceSource> sources = const <EvidenceSource>[],
    EnemyReminder reminder = const NoopEnemyReminder(),
  }) {
    return _EnemyLoader(
      db: db,
      oracle: oracle,
      talker: talker,
      voice: voice,
      sources: sources,
      reminder: reminder,
    );
  }
}

class _EnemyLoader extends StatefulWidget {
  const _EnemyLoader({
    required this.db,
    required this.oracle,
    required this.talker,
    required this.voice,
    required this.sources,
    required this.reminder,
  });

  final Database db;
  final EnemyOracle oracle;
  final EnemyTalker? talker;
  final EnemyVoiceOut voice;
  final List<EvidenceSource> sources;
  final EnemyReminder reminder;

  @override
  State<_EnemyLoader> createState() => _EnemyLoaderState();
}

class _EnemyLoaderState extends State<_EnemyLoader> {
  late final Future<EnemyPresence> _presence = EnemyEntry.buildPresence(
    db: widget.db,
    oracle: widget.oracle,
    talker: widget.talker,
    sources: widget.sources,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EnemyPresence>(
      future: _presence,
      builder: (BuildContext context, AsyncSnapshot<EnemyPresence> snapshot) {
        final EnemyPresence? presence = snapshot.data;
        if (presence == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF14100F),
            body: SizedBox.shrink(),
          );
        }
        return EnemyHomePage(
          presence: presence,
          voice: widget.voice,
          reminder: widget.reminder,
        );
      },
    );
  }
}
