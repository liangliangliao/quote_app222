import 'dart:io';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'batch_request.dart';
import 'classifier.dart';
import 'cost_policy.dart';
import 'models.dart';
import 'repository.dart';
import 'schema.dart';

class QuoteKnowledgeWorker {
  final QuoteKnowledgeRepository repository;
  final QuoteKnowledgeClassifier classifier;
  final bool localFirst;
  bool _running = false;
  QuoteKnowledgeWorker(
      {QuoteKnowledgeRepository? repository,
      QuoteKnowledgeClassifier? classifier,
      this.localFirst = true})
      : repository = repository ?? QuoteKnowledgeRepository(),
        classifier = classifier ?? QuoteKnowledgeClassifier();

  /// One drain sends at most one bounded batch; the durable round allowance is
  /// shared with other workers, foreground launches and scheduled tasks.
  Future<int> drain({int limit = ClassificationCostPolicy.batchSize}) async {
    if (_running) return 0;
    _running = true;
    final pending = <ClassificationClaim>[],
        groups = <String, List<ClassificationClaim>>{};
    var completed = 0, characters = 0;
    try {
      for (var i = 0; i < limit.clamp(1, 64); i++) {
        final c = await repository.claim();
        if (c == null) break;
        final cached = await repository.cachedClassification(c);
        if (cached != null) {
          if (await repository.apply(c, cached, method: 'cache')) completed++;
          continue;
        }
        if (localFirst &&
            c.strategy != 'ai' &&
            await repository.localMatch(c)) {
          completed++;
          continue;
        }
        final key = '${c.quote['content']}'.trim();
        if (key.runes.length > ClassificationCostPolicy.maxQuoteCharacters) {
          await repository.hold(c, message: '原文较长，已暂停自动请求，可人工分类。');
          continue;
        }
        if (!groups.containsKey(key) &&
            (groups.length >= ClassificationCostPolicy.batchSize ||
                characters + key.runes.length >
                    ClassificationCostPolicy.maxQuoteCharacters)) {
          await repository.hold(c, busy: true);
          break;
        }
        if (!groups.containsKey(key)) {
          groups[key] = [];
          characters += key.runes.length;
        }
        groups[key]!.add(c);
        pending.add(c);
      }
      if (pending.isEmpty) return completed;
      final unique = groups.values.map((g) => g.first).toList();
      BatchClassificationRequest request;
      try {
        request = BatchClassificationRequest(
            unique,
            await repository.candidates(
                {'content': unique.map((c) => c.quote['content']).join('\n')},
                limit: 24));
        request.prompt;
      } catch (_) {
        for (final c in pending) {
          await repository.hold(c, message: '本批材料超过紧凑整理上限，可人工分类。');
        }
        return completed;
      }
      // Check availability before reserving billable work or increasing counters.
      final config = await classifier.ai.resolveGlobalConfig();
      if (!config.available) {
        for (final c in pending) {
          await repository.provisional(c);
          await repository.hold(c, message: '请配置全局文字AI，已暂停请求并保留本地初分。');
        }
        return completed;
      }
      final reservation =
          await repository.reserveRequest(pending, request.estimatedTokens);
      if (reservation.state != 'ready') {
        for (final c in pending) {
          await repository.hold(c,
              budget: reservation.state == 'budget',
              busy: reservation.state != 'budget',
              message: reservation.state == 'budget'
                  ? '本轮AI请求次数已用完或暂停，请按需继续下一轮。'
                  : '');
        }
        return completed;
      }
      var failed = false;
      try {
        final results = await classifier.classifyBatch(request);
        for (final group in groups.values) {
          final result = results[group.first.quoteKey];
          for (final c in group) {
            if (result == null) {
              failed = true;
              await repository.provisional(c);
              await repository.retryFailure(c, '本条未返回有效原句依据。');
            } else {
              try {
                if (await repository.apply(c, result,
                    method: c == group.first ? 'ai' : 'batch')) completed++;
              } catch (_) {
                failed = true;
                await repository.retryFailure(c, '分类已变化。');
              }
            }
          }
        }
      } catch (error) {
        failed = true;
        for (final c in pending) {
          await repository.provisional(c);
          if (error is TimeoutException ||
              error is SocketException ||
              error is HttpException ||
              error is http.ClientException) {
            await repository.hold(c,
                message: '请求超时或连接中断，无法确认是否已计费，已暂停自动重发；可手动重试。');
          } else {
            await repository.retryFailure(c, '本批AI请求未完成。');
          }
        }
      } finally {
        await repository.finishRequest(reservation.id, failed: failed);
      }
      return completed;
    } finally {
      _running = false;
    }
  }
}

class QuoteKnowledgeRuntime with WidgetsBindingObserver {
  static final instance = QuoteKnowledgeRuntime();
  final QuoteKnowledgeWorker worker;
  Timer? _timer, _debounce;
  StreamSubscription<void>? _subscription;
  bool _started = false, _foreground = true;
  QuoteKnowledgeRuntime({QuoteKnowledgeWorker? worker})
      : worker = worker ?? QuoteKnowledgeWorker();
  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _subscription = QuoteKnowledgeEvents.changes.listen((_) => kick());
    _timer = Timer.periodic(const Duration(seconds: 35), (_) => kick());
    unawaited(_indexLegacy());
    kick();
  }

  Future<void> _indexLegacy() async {
    try {
      while (_started && await worker.repository.bootstrapLegacy() == 200) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    } catch (_) {}
  }

  void kick() {
    if (!_started || !_foreground || _debounce?.isActive == true) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await worker.drain(limit: 64);
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) kick();
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _debounce?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
