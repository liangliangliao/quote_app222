import 'package:flutter_test/flutter_test.dart';
import 'package:quote_app/will_module/will_route_resolver.dart';
import 'package:quote_app/will_module/will_unit_index_seed.dart';

void main() {
  test('关键单元 P-017 能解析到抗诱惑路径', () {
    final unit = kWillUnitIndexes.firstWhere((e) => e.id == 'P-017');
    final tasks = WillRouteResolver.recommendedTasksForUnit(unit).map((e) => e.title).toList();
    final zones = WillRouteResolver.recommendedZonesForUnit(unit).map((e) => e.title).toList();
    expect(tasks, contains('90 秒延迟诱惑'));
    expect(zones, contains('诱惑市集'));
  });

  test('导论 D-015 会推荐流程感相关训练', () {
    final unit = kWillUnitIndexes.firstWhere((e) => e.id == 'D-015');
    final tasks = WillRouteResolver.recommendedTasksForUnit(unit).map((e) => e.title).toList();
    expect(tasks, contains('30 秒注意锁定'));
  });
}
