import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/quote_insight.dart';
import 'cognitive_store.dart';
import 'semantic_scope.dart';

class SavedSemanticAnalysis {
  final String id,
      session,
      focus,
      inquiry,
      status,
      raw,
      error,
      kind,
      purpose,
      conditions;
  final DateTime at;
  final List<ScopeSource> sources;
  final SemanticScope? analysis;
  const SavedSemanticAnalysis(
      {required this.id,
      required this.session,
      required this.focus,
      required this.inquiry,
      required this.status,
      required this.raw,
      required this.error,
      required this.at,
      required this.sources,
      this.analysis,
      this.kind = 'analysis',
      this.purpose = '',
      this.conditions = ''});
  factory SavedSemanticAnalysis.parse(dynamic value) {
    final m = insightObject(value);
    final sources = [
      for (final s in m['sources'] is List ? m['sources'] as List : const [])
        ScopeSource('${s['id']}', '${s['text']}',
            title: '${s['title'] ?? ''}', origin: '${s['origin'] ?? 'quote'}')
    ];
    return SavedSemanticAnalysis(
        id: '${m['id']}',
        session: '${m['session']}',
        focus: '${m['focus']}',
        inquiry: '${m['inquiry'] ?? ''}',
        status: '${m['status']}',
        raw: '${m['raw'] ?? ''}',
        error: '${m['error'] ?? ''}',
        at: DateTime.parse('${m['at']}'),
        sources: sources,
        kind: '${m['kind'] ?? 'analysis'}',
        purpose: '${m['purpose'] ?? ''}',
        conditions: '${m['conditions'] ?? ''}',
        analysis: m['analysis'] is Map
            ? SemanticScope.parse(m['analysis'], sources,
                model: '${m['model'] ?? ''}')
            : null);
  }
}

/// Durable revisions shared by reading projections and library relationship
/// views. Partial results and failed attempts never erase the last usable one.
class SemanticAnalysisArchive {
  final Future<Database> Function() database;
  SemanticAnalysisArchive({Future<Database> Function()? database})
      : database = database ?? (() => CognitiveStore().database);
  Future<Database> _db() async {
    final db = await database();
    await db.execute(
        'CREATE TABLE IF NOT EXISTS app_kv (key TEXT PRIMARY KEY, value TEXT)');
    return db;
  }

  static const prefix = 'cognition.scope.saved.v1.';
  static final changes = StreamController<void>.broadcast();
  static int _serial = 0;
  static String sessionKey(
          List<ScopeSource> sources, String focus, SemanticContext context) =>
      insightHash([
        sources
            .map((s) => {'id': s.id, 'text': s.text, 'origin': s.origin})
            .toList(),
        context.purpose.isEmpty ? focus : context.purpose,
        if (context.conditions.isNotEmpty) context.conditions,
      ]);
  Future<SavedSemanticAnalysis> save(
      List<ScopeSource> sources, String focus, SemanticContext context,
      {SemanticScope? analysis,
      String raw = '',
      String error = '',
      bool activate = true}) async {
    final db = await _db();
    final session = sessionKey(sources, focus, context),
        now = DateTime.now().toUtc();
    final id = '$prefix$session.${now.microsecondsSinceEpoch}-${++_serial}';
    final status = analysis == null
        ? 'failed'
        : analysis.needsRepair
            ? 'partial'
            : 'complete';
    final value = {
      'id': id,
      'session': session,
      'focus': focus,
      'inquiry': context.inquiry,
      'purpose': context.purpose,
      'conditions': context.conditions,
      'kind': context.conceptId.isEmpty ? 'analysis' : 'branch',
      'at': now.toIso8601String(),
      'status': status,
      'raw': raw,
      'error': error,
      'model': analysis?.model ?? '',
      'sources': sources.map((s) => s.toJson()).toList(),
      if (analysis != null) 'analysis': analysis.toJson()
    };
    await db.transaction((txn) async {
      await txn.insert('app_kv', {'key': id, 'value': jsonEncode(value)});
      if (activate && analysis != null)
        await txn.insert(
            'app_kv', {'key': '$prefix$currentMarker$session', 'value': id},
            conflictAlgorithm: ConflictAlgorithm.replace);
    });
    changes.add(null);
    return SavedSemanticAnalysis.parse(value);
  }

  static const currentMarker = 'current.';
  Future<List<SavedSemanticAnalysis>> history(
      List<ScopeSource> sources, String focus, SemanticContext context) async {
    final db = await _db(), session = sessionKey(sources, focus, context);
    return _parse(await db.query('app_kv',
            columns: ['value'],
            where: 'key GLOB ?',
            whereArgs: ['$prefix$session.*'],
            orderBy: 'rowid DESC'))
        .where((s) => s.kind != 'branch')
        .toList();
  }

  Future<SavedSemanticAnalysis?> current(
      List<ScopeSource> sources, String focus, SemanticContext context) async {
    final db = await _db(), session = sessionKey(sources, focus, context);
    final pointer = await db.query('app_kv',
        columns: ['value'],
        where: 'key=?',
        whereArgs: ['$prefix$currentMarker$session'],
        limit: 1);
    if (pointer.isNotEmpty) {
      final rows = await db.query('app_kv',
          columns: ['value'],
          where: 'key=?',
          whereArgs: [pointer.single['value']],
          limit: 1);
      final saved = _parse(rows).firstOrNull;
      if (saved?.analysis != null) return saved;
    }
    return (await history(sources, focus, context))
        .where((s) => s.analysis != null)
        .firstOrNull;
  }

  Future<void> select(SavedSemanticAnalysis item) async {
    if (item.analysis == null) throw StateError('该次没有可展示的分析');
    final db = await _db();
    await db.insert('app_kv',
        {'key': '$prefix$currentMarker${item.session}', 'value': item.id},
        conflictAlgorithm: ConflictAlgorithm.replace);
    changes.add(null);
  }

  Future<List<SavedSemanticAnalysis>> forLibrary(Iterable<String> texts) async {
    final allowed = texts.map((s) => insightHash(s)).toSet();
    if (allowed.isEmpty) return [];
    final db = await _db();
    final pointers = {
      for (final row in await db.query('app_kv',
          columns: ['key', 'value'],
          where: 'key GLOB ?',
          whereArgs: ['$prefix$currentMarker*']))
        '${row['key']}'.substring('$prefix$currentMarker'.length):
            '${row['value']}'
    };
    // Load selected versions only; keeping failed/raw revisions locally must
    // not make every library visit parse the entire revision archive.
    final keys =
        pointers.values.where((id) => id.startsWith(prefix)).toSet().toList();
    final values = <SavedSemanticAnalysis>[];
    for (var i = 0; i < keys.length; i += 150) {
      final chunk = keys.skip(i).take(150).toList();
      values.addAll(_parse(await db.query('app_kv',
          columns: ['value'],
          where: 'key IN (${List.filled(chunk.length, '?').join(',')})',
          whereArgs: chunk)));
    }
    final validSessions = values
        .where((v) => v.analysis != null && pointers[v.session] == v.id)
        .map((v) => v.session)
        .toSet();
    for (final session
        in pointers.keys.where((s) => !validSessions.contains(s))) {
      final recovered = _parse(await db.query('app_kv',
              columns: ['value'],
              where: 'key GLOB ?',
              whereArgs: ['$prefix$session.*'],
              orderBy: 'rowid DESC'))
          .where((v) => v.analysis != null && v.kind != 'branch')
          .firstOrNull;
      if (recovered != null) {
        values.add(recovered);
        pointers[session] = recovered.id;
      }
    }
    values.sort((a, b) => b.at.compareTo(a.at));
    final sessions = <String>{};
    return values
        .where((v) =>
            v.kind != 'branch' &&
            v.analysis != null &&
            (!pointers.containsKey(v.session) || pointers[v.session] == v.id) &&
            v.sources.every((s) =>
                s.origin == 'quote' && allowed.contains(insightHash(s.text))) &&
            sessions.add(v.session))
        .toList();
  }

  List<SavedSemanticAnalysis> _parse(List<Map<String, Object?>> rows) {
    final result = <SavedSemanticAnalysis>[];
    for (final row in rows) {
      try {
        result.add(SavedSemanticAnalysis.parse(row['value']));
      } catch (_) {/* Isolate one damaged revision, preserve others. */}
    }
    return result;
  }
}
