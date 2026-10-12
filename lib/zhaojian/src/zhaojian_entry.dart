import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'domain/controller.dart';
import 'ui/home_page.dart';
import 'zhaojian_oracle.dart';

/// 模块入口。宿主只需要这一个 Widget 与一个路由常量。
///
/// 模块不自己开库：宿主把已经打开的 Database 传进来，模块只读写 `z_` 前缀表。
class ZhaojianEntry extends StatefulWidget {
  const ZhaojianEntry({
    super.key,
    required this.db,
    this.oracle = const LocalZhaojianOracle(),
  });

  /// 路由名。宿主可在 routes 里注册，也可以直接 push [build] 出来的 Widget。
  static const String route = '/zhaojian';

  final Database db;
  final ZhaojianOracle oracle;

  /// 集成契约里的构造入口。
  static Widget build({
    required Database db,
    ZhaojianOracle oracle = const LocalZhaojianOracle(),
  }) {
    return ZhaojianEntry(db: db, oracle: oracle);
  }

  @override
  State<ZhaojianEntry> createState() => _ZhaojianEntryState();
}

class _ZhaojianEntryState extends State<ZhaojianEntry> {
  late final ZhaojianController _controller =
      ZhaojianController(db: widget.db, oracle: widget.oracle);

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ZhaojianHomePage(controller: _controller);
  }
}
