import 'cognitive_mode.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/quote_insight.dart';
import 'cognitive_store.dart';

/// Append-only snapshots scoped to the selected pair. Restoring a judgment
/// appends a revision; it never deletes the intervening evidence or originals.
class ComparisonRevisionStore {
  final CognitiveStore store;
  ComparisonRevisionStore({CognitiveStore? store})
      : store = store ?? CognitiveStore();
  String _key(QuoteReference a, QuoteReference b) =>
      'cognition.comparison_revisions.v1.${insightHash([
            a.id,
            a.contentKey,
            b.id,
            b.contentKey
          ])}';
  Future<List<Map<String, dynamic>>> read(
      QuoteReference a, QuoteReference b) async {
    final db = await store.database;
    final rows =
        await db.query('app_kv', where: 'key=?', whereArgs: [_key(a, b)]);
    final raw = rows.isEmpty ? [] : jsonDecode('${rows.first['value']}');
    return raw is List
        ? raw.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
        : [];
  }

  Future<void> append(QuoteReference a, QuoteReference b, QuoteComparison value,
      String purpose, String conditions,
      {String restoredFrom = '', String? userReason}) async {
    final db = await store.database;
    await db.transaction((txn) async {
      final rows =
          await txn.query('app_kv', where: 'key=?', whereArgs: [_key(a, b)]);
      final raw = rows.isEmpty ? [] : jsonDecode('${rows.first['value']}');
      final history = raw is List
          ? raw
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList()
          : <Map<String, dynamic>>[];
      final previous = history.lastOrNull;
      if (previous != null &&
          restoredFrom.isEmpty &&
          previous['purpose'] == purpose &&
          previous['conditions'] == conditions &&
          insightHash(previous['result']) == insightHash(value.toJson()))
        return;
      history.add({
        'id': '${DateTime.now().microsecondsSinceEpoch}-${history.length}',
        'at': DateTime.now().toIso8601String(),
        'purpose': purpose,
        'conditions': conditions,
        'previous_id': previous?['id'],
        'previous_purpose': previous?['purpose'],
        'previous_conditions': previous?['conditions'],
        'previous_difference': previous == null
            ? ''
            : insightText(
                insightObject(previous['result']), 'critical_difference'),
        'decisive_difference': value.difference,
        'evidence': value.justification,
        'revision_trigger': value.limitation,
        'restored_from': restoredFrom,
        'reason': userReason ??
            (previous == null
                ? '记录本次有条件判断'
                : restoredFrom.isNotEmpty
                    ? '手动恢复旧判断，保留全部中间修订'
                    : previous['purpose'] == purpose
                        ? '条件由${previous['conditions']}改为$conditions；依新条件重新识别决定性差异'
                        : '从${previous['purpose']}转为$purpose；依本次目的与条件重新识别决定性差异'),
        'result': value.toJson(),
      });
      await txn.insert(
          'app_kv', {'key': _key(a, b), 'value': jsonEncode(history)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}

class ComparisonRevisionView extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final ValueChanged<Map<String, dynamic>>? onRestore;
  const ComparisonRevisionView(
      {super.key, required this.history, this.onRestore});
  @override
  Widget build(BuildContext context) => ExpansionTile(
        expansionAnimationStyle: cognitiveExpansionStyle(context),
        title: Text('判断修订记录 · ${history.length}'),
        children: [
          for (final row in history.reversed)
            ListTile(
              title: Text('${row['purpose']} · ${row['at']}'),
              subtitle: Text(
                  '条件：${row['conditions']}\n原差异：${row['previous_difference']}\n'
                  '当前决定性差异：${row['decisive_difference']}\n依据：${row['evidence']}\n'
                  '改判条件：${row['revision_trigger']}\n修订理由：${row['reason']}'),
              trailing: onRestore == null
                  ? null
                  : IconButton(
                      tooltip: '恢复此判断并保留修订历史',
                      onPressed: () => onRestore!(row),
                      icon: const Icon(Icons.restore)),
            )
        ],
      );
}
