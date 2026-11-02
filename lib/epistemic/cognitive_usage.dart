import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/quote_insight.dart';
import 'cognitive_preferences.dart';
import 'cognitive_store.dart';

enum CognitiveEvent {
  visualOpened('展开画面对应'),
  exampleOpened('展开具体实例'),
  differenceOpened('展开同异与边界'),
  basisOpened('展开判断依据'),
  analysisRequested('主动分析'),
  accepted('采纳建议'),
  acceptanceUndone('撤销采纳'),
  classificationChanged('修正分类'),
  classificationUndone('撤销分类修正'),
  skipped('跳过建议'),
  deleted('删除注释'),
  revised('保存判断修订'),
  rolledBack('回退判断'),
  hintShown('显示范围轻提示'),
  hintSkipped('跳过范围提示'),
  recapRequested('主动回顾'),
  invalidOutput('输出格式错误'),
  requestFailed('分析暂不可用'),
  storageFailed('附属存储错误');

  final String label;
  const CognitiveEvent(this.label);
}

/// Optional local aggregate counters. The API deliberately accepts no content,
/// record IDs, timestamps, device identifiers, prompts or exception strings.
class CognitiveUsageStore {
  static final instance = CognitiveUsageStore();
  static const key = 'cognition.usage.aggregate.v1';
  final CognitiveStore _store;
  final bool Function() _allowed;
  CognitiveUsageStore({CognitiveStore? store, bool Function()? allowed})
      : _store = store ?? CognitiveStore(),
        _allowed = allowed ??
            (() =>
                CognitivePreferenceStore.active &&
                CognitivePreferenceStore.instance.value.usageEnabled);

  static Map<CognitiveEvent, int> _parse(dynamic value) {
    final m = insightObject(value);
    return {
      for (final event in CognitiveEvent.values)
        if (m[event.name] is int && (m[event.name] as int) > 0)
          event: (m[event.name] as int).clamp(0, 1000000).toInt()
    };
  }

  void track(CognitiveEvent event) => unawaited(record(event));

  Future<void> record(CognitiveEvent event) async {
    if (!_allowed()) return;
    try {
      final db = await _store.database;
      await db.transaction((txn) async {
        if (!_allowed()) return;
        final rows =
            await txn.query('app_kv', where: 'key=?', whereArgs: [key]);
        final counters = _parse(rows.isEmpty ? null : rows.first['value']);
        if (!_allowed()) return;
        counters[event] =
            ((counters[event] ?? 0) + 1).clamp(0, 1000000).toInt();
        await txn.insert(
            'app_kv',
            {
              'key': key,
              'value': jsonEncode(
                  {for (final e in counters.entries) e.key.name: e.value})
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } catch (_) {/* Observation never blocks reading, saving or analysis. */}
  }

  Future<Map<CognitiveEvent, int>> read() async {
    final db = await _store.database;
    final rows = await db.query('app_kv', where: 'key=?', whereArgs: [key]);
    return _parse(rows.isEmpty ? null : rows.first['value']);
  }

  Future<void> clear() async {
    final db = await _store.database;
    await db.delete('app_kv', where: 'key=?', whereArgs: [key]);
  }
}
