import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'domain/controller.dart';
import 'kindling_oracle.dart';
import 'ui/list_page.dart';

/// 模块入口。宿主只需要这一个 Widget 与一个路由常量。
///
/// 模块不自己开库：宿主把已经打开的 Database 传进来，模块只读写 `k_` 前缀表。
class KindlingEntry extends StatefulWidget {
  const KindlingEntry({
    super.key,
    required this.db,
    this.oracle = const LocalOracle(),
  });

  /// 路由名。宿主可在 routes 里注册，也可以直接 push [build] 出来的 Widget。
  static const String route = '/kindling';

  final Database db;
  final KindlingOracle oracle;

  /// 集成契约里的构造入口。
  static Widget build({
    required Database db,
    KindlingOracle oracle = const LocalOracle(),
  }) {
    return KindlingEntry(db: db, oracle: oracle);
  }

  @override
  State<KindlingEntry> createState() => _KindlingEntryState();
}

class _KindlingEntryState extends State<KindlingEntry> {
  late final KindlingController _controller = KindlingController(
    db: widget.db,
    oracle: widget.oracle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KindlingListPage(controller: _controller);
  }
}
