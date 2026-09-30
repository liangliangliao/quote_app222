import 'package:sqflite/sqflite.dart';

import '../data/models.dart';

/// 一个可以给敌人提供证据的来源。
///
/// 来源实现放在宿主侧（它们要读宿主自己的表），模块只认这个接口。
/// 新增一个被追踪的模块，就是新增一个实现类，模块本体不用改。
abstract class EvidenceSource {
  /// 稳定的来源标识，同时也是授权开关的键，例如 habit / kindling。
  String get id;

  /// 界面上显示的名字。
  String get label;

  /// 收集 [sinceMs] 之后发生的事件。
  ///
  /// 必须是幂等的：同一件事每次都产出同一个 dedupeKey，重复调用不会重复入库。
  /// 表不存在或读失败时返回空列表，不要抛。
  Future<List<EventDraft>> collect(Database db, int sinceMs);
}
