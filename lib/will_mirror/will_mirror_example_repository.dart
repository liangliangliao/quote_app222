import 'dart:convert';

import 'package:flutter/services.dart';

import 'will_mirror_capability_catalog.dart';
import 'will_mirror_practice_models.dart';

class WillMirrorExampleRepository {
  WillMirrorExampleRepository({
    Future<String> Function(String key)? assetLoader,
  }) : _assetLoader = assetLoader;

  static const String asset = 'assets/will_mirror/example_cases_v5.json';

  final Future<String> Function(String key)? _assetLoader;
  List<WillMirrorExampleCase>? _cache;

  Future<List<WillMirrorExampleCase>> load() async {
    if (_cache != null) return _cache!;
    final raw = _assetLoader == null
        ? await rootBundle.loadString(asset)
        : await _assetLoader(asset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['cases'] is! List) {
      throw const FormatException('默认案例文件缺少 cases 数组');
    }
    final cases = (decoded['cases'] as List)
        .whereType<Map>()
        .map(
          (item) => WillMirrorExampleCase.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
    final issues = validate(cases);
    if (issues.isNotEmpty) {
      throw StateError('默认案例校验失败：${issues.join('；')}');
    }
    _cache = List<WillMirrorExampleCase>.unmodifiable(cases);
    return _cache!;
  }

  static List<String> validate(List<WillMirrorExampleCase> cases) {
    final issues = <String>[];
    final ids = <String>{};
    if (cases.length < 3) issues.add('至少需要三个完整案例');
    for (final item in cases) {
      if (item.id.isEmpty || !ids.add(item.id)) {
        issues.add('案例 id 缺失或重复：${item.id}');
      }
      if (item.need.isEmpty ||
          item.desiredOutcome.isEmpty ||
          item.generatedAction.isEmpty ||
          item.successSignal.isEmpty ||
          item.whyItWorks.isEmpty ||
          item.theoryApplications.isEmpty ||
          item.generationReceipt.isEmpty) {
        issues.add('${item.id} 缺少输入、产出或完成信号');
      }
      if (item.days.length != 7) issues.add('${item.id} 必须保留七天测试数据');
      if (!item.days.any((day) => !day.didAct)) {
        issues.add('${item.id} 缺少“没做成也作为证据”的案例');
      }
      if (item.result.isEmpty || item.nextRevision.isEmpty) {
        issues.add('${item.id} 缺少结果或下一轮修订');
      }
      for (final theoryId in item.theoryIds) {
        if (!WillMirrorTheoryCatalog.byId.containsKey(theoryId)) {
          issues.add('${item.id} 引用了未知理论：$theoryId');
        }
      }
      for (final application in item.theoryApplications) {
        if (!item.theoryIds.contains(application.theoryId) ||
            application.application.isEmpty ||
            application.reason.isEmpty) {
          issues.add('${item.id} 的理论应用说明不完整');
        }
      }
    }
    return issues;
  }
}
