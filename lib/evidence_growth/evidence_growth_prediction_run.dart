import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'evidence_growth_dao.dart';
import 'evidence_growth_journey_models.dart';

/// Classifies failures without retaining provider response bodies or secrets.
class EvidencePredictionFailure {
  static GrowthData classify(Object error) {
    if (error is TimeoutException) return {'reason': 'REQUEST_TIMEOUT'};
    if (error is FormatException) {
      return {
        'reason': 'RESPONSE_PARSE_FAILED',
        'detail_code': RegExp(r'^[A-Z][A-Z0-9_]{0,80}$').hasMatch(error.message)
            ? error.message
            : 'INVALID_JSON'
      };
    }
    if (error is http.ClientException) return {'reason': 'NETWORK_ERROR'};
    final message = '$error';
    final status = RegExp(r'\bHTTP[ _:]*(\d{3})\b', caseSensitive: false)
        .firstMatch(message);
    if (status != null) {
      final code = int.parse(status.group(1)!);
      if (code >= 200 && code < 300) {
        return {'reason': 'EMPTY_AI_RESPONSE', 'http_status': code};
      }
      return {'reason': 'HTTP_$code', 'http_status': code};
    }
    if (RegExp(r'timeout|timed out', caseSensitive: false).hasMatch(message)) {
      return {'reason': 'REQUEST_TIMEOUT'};
    }
    if (RegExp(
            r'SocketException|HandshakeException|connection (closed|reset|refused)|failed host lookup|network',
            caseSensitive: false)
        .hasMatch(message)) {
      return {'reason': 'NETWORK_ERROR'};
    }
    return {'reason': 'AI_REQUEST_FAILED'};
  }
}

/// A small persistent journal for an explicitly resumed prediction. Exact
/// inputs, model identity and upstream results determine stage reuse. Failed
/// stages are never treated as completed, and downstream results are invalidated
/// when an upstream answer changes.
class EvidencePredictionRun {
  EvidencePredictionRun._(this._dao, this.id, this._state, this._stages,
      this.onStageChanged, this._queue);

  static const version = 'prediction_stages_v1';
  static const setting = 'action_prediction_pending_stages_v1';
  static final _queues = Expando<_PredictionWriteQueue>();
  final EvidenceGrowthDao _dao;
  final String id;
  final GrowthData _state;
  final GrowthData _stages;
  final _PredictionWriteQueue _queue;
  final void Function(String stage)? onStageChanged;
  final reusedStages = <String>[];
  GrowthData stageResult(String name) =>
      growthMap(growthMap(_stages[name])['result']);

  static String fingerprint(Object? value) =>
      sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();

  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      return {for (final key in keys) key: _canonical(value[key])};
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  static Future<GrowthData> _read(EvidenceGrowthDao dao) async {
    final raw = await dao.getSetting(setting);
    try {
      return raw.isEmpty ? {} : growthMap(jsonDecode(raw));
    } on FormatException {
      return {};
    }
  }

  static Future<EvidencePredictionRun> open({
    required EvidenceGrowthDao dao,
    required String id,
    required GrowthData state,
    bool resume = false,
    void Function(String stage)? onStageChanged,
  }) async {
    final saved =
        resume ? growthMap((await _read(dao))[id]) : <String, dynamic>{};
    final reusable = saved['version'] == version &&
        saved['state_hash'] == fingerprint(state);
    final queue = _queues[dao] ??= _PredictionWriteQueue();
    return EvidencePredictionRun._(dao, id, state,
        reusable ? growthMap(saved['stages']) : {}, onStageChanged, queue);
  }

  Future<void> _checkpoint() {
    // Independent first passes finish concurrently. Serialize read-modify-write
    // operations so neither success can erase the other, including across runs.
    final write = _queue.tail.then((_) async {
      final runs = await _read(_dao);
      runs.remove(id);
      runs[id] = {
        'version': version,
        'state_hash': fingerprint(_state),
        'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
        'stages': _stages,
      };
      while (runs.length > 8) {
        runs.remove(runs.keys.first);
      }
      await _dao.setSetting(setting, jsonEncode(runs));
    });
    _queue.tail = write.catchError((Object _) {});
    return write;
  }

  Future<GrowthData> stage(
    String name, {
    required GrowthData identity,
    GrowthData dependencies = const {},
    GrowthData seed = const {},
    required bool Function(GrowthData result) complete,
    required Future<GrowthData> Function() execute,
  }) async {
    final key = fingerprint({
      'version': version,
      'stage': name,
      'state': _state,
      'identity': identity,
      'dependencies': dependencies,
    });
    final cached = growthMap(_stages[name]);
    final cachedResult = growthMap(cached['result']);
    if (cached['fingerprint'] == key && complete(cachedResult)) {
      reusedStages.add(name);
      return cachedResult;
    }
    if (cached.isEmpty && complete(seed)) {
      _stages[name] = {
        'fingerprint': key,
        'result': seed,
        'status': 'COMPLETE'
      };
      await _checkpoint();
      reusedStages.add(name);
      return seed;
    }
    onStageChanged?.call(name);
    _stages[name] = {'fingerprint': key, 'status': 'RUNNING'};
    await _checkpoint();
    GrowthData result;
    try {
      result = await execute();
    } catch (error) {
      result = {
        'status': 'LOCAL',
        ...EvidencePredictionFailure.classify(error)
      };
    }
    _stages[name] = {
      'fingerprint': key,
      'result': result,
      'status': complete(result) ? 'COMPLETE' : 'PARTIAL',
    };
    await _checkpoint();
    return result;
  }
}

class _PredictionWriteQueue {
  Future<void> tail = Future<void>.value();
}
