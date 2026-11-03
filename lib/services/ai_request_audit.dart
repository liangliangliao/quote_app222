import 'dart:async';
import 'dart:convert';
import '../data/kv_dao.dart';
import '../utils/deepseek_logger.dart';
import 'ai_request_accounting.dart';
import 'global_ai_request_settings.dart';

class AiOperation {
  final String id, purpose;
  final cancellation = AiCancellation();
  final List<Map<String, dynamic>> attempts = [];
  AiOutputBudget? budget;
  AiOperation(this.purpose)
      : id = '${DateTime.now().microsecondsSinceEpoch}-${++_serial}';
  static int _serial = 0;
}

/// An isolated scope per caller, including concurrent requests. No global
/// mutable "last request" can attach another user's result to an operation.
class AiRequestAudit {
  static final taskOverrides = <String, int>{};
  static List<Map<String, dynamic>> recent = [];
  static Future<void>? _initializing;
  static final budgetChanges = StreamController<void>.broadcast();
  static Future<void> initialize() => _initializing ??= (() async {
        try {
          await GlobalAiRequestSettings().getConfig();
          for (final row
              in await KeyValueDao().keyValuesWithPrefix('ai.task_budget.')) {
            final value = int.tryParse(row['value'] ?? '');
            if (value != null && value > 0)
              taskOverrides[(row['key'] ?? '')
                  .substring('ai.task_budget.'.length)] = value;
          }
          recent = await history();
          budgetChanges.add(null);
        } catch (_) {
          _initializing = null;
        }
      })();
  static final _zoneKey = Object();
  static AiOperation? get current => Zone.current[_zoneKey] as AiOperation?;
  static final updates = StreamController<Map<String, dynamic>>.broadcast();
  static Future<T> run<T>(String purpose, Future<T> Function() work) =>
      current != null ? work() : runOperation(AiOperation(purpose), work);
  static Future<T> runOperation<T>(
          AiOperation operation, Future<T> Function() work) =>
      runZoned(work, zoneValues: {_zoneKey: operation});
  static String budgetKey(String purpose) =>
      purpose.replaceFirst(RegExp(r'\.v\d+$'), '');
  static Future<AiOutputBudget> resolve(
      String purpose, int requested, GlobalAiRequestConfig config) async {
    final raw =
        await KeyValueDao().getString('ai.task_budget.${budgetKey(purpose)}');
    final override = int.tryParse(raw ?? '');
    if (override != null && override > 0)
      taskOverrides[budgetKey(purpose)] = override;
    else
      taskOverrides.remove(budgetKey(purpose));
    final budget = AiOutputBudget.resolve(
        override != null && override > 0 ? override : requested,
        global: config.maxOutputTokens);
    current?.budget = budget;
    budgetChanges.add(null);
    return budget;
  }

  static Future<void> setBudget(String purpose, int value) async {
    if (value <= 0) throw ArgumentError('输出额度须为正整数');
    await KeyValueDao()
        .setString('ai.task_budget.${budgetKey(purpose)}', '$value');
    taskOverrides[budgetKey(purpose)] = value;
    budgetChanges.add(null);
  }

  static Future<void> record(
      {required String provider,
      required String model,
      required String purpose,
      required Map<String, dynamic> body,
      String response = '',
      int? status,
      String? failure}) async {
    final operation = current;
    final budget = operation?.budget?.toJson() ?? <String, dynamic>{};
    budget['effective'] = body['max_output_tokens'] ??
        body['max_completion_tokens'] ??
        body['max_tokens'];
    final row = <String, dynamic>{
      'operation_id':
          operation?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
      'at': DateTime.now().toIso8601String(),
      'purpose': purpose,
      'provider': provider,
      'model': model,
      'budget': budget,
      'request_parameters': {
        for (final key in [
          'temperature',
          'top_p',
          'stream',
          'max_tokens',
          'max_completion_tokens',
          'max_output_tokens'
        ])
          if (body.containsKey(key)) key: body[key]
      },
      'usage': AiTokenUsage.parse(response).toJson(),
      'status': status,
      'finish_reason': aiFinishReason(response),
      'failure': failure,
    };
    operation?.attempts.add(row);
    recent = [row, ...recent].take(100).toList();
    updates.add(row);
    // Telemetry must never turn a successful generation into a failure.
    try {
      await _persist(row);
      await DeepSeekLogger.logResponse(
          module: 'ai.usage.$purpose',
          endpoint: '',
          statusCode: status ?? 0,
          body: row,
          provider: provider,
          model: model);
    } catch (_) {}
  }

  static Future<void> _writes = Future.value();
  static Future<void> _persist(Map<String, dynamic> row) {
    final next = _writes.then((_) async {
      final rows = await history();
      rows.insert(0, row);
      await KeyValueDao().setString(
          'ai.request_usage.v1', jsonEncode(rows.take(100).toList()));
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  static Future<List<Map<String, dynamic>>> history() async {
    try {
      final raw = jsonDecode(
          await KeyValueDao().getString('ai.request_usage.v1') ?? '[]');
      return raw is List
          ? raw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList()
          : [];
    } catch (_) {
      return [];
    }
  }
}
